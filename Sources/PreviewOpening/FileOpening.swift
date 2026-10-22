import Foundation
import Security

@objc(FileglintFileOpening)
public protocol FileOpeningXPC {
    func openFile(_ bookmark: Data, sourcePath: String, applicationPath: String, withReply reply: @escaping (String?) -> Void)
}

@objc(FileglintOpeningBootstrap)
public protocol OpeningBootstrapXPC {
    func connect(_ bundleBookmark: Data, withReply reply: @escaping (NSXPCListenerEndpoint?, String?) -> Void)
}

public enum PeerTrust {
    /// Bootstrap access is restricted to the service's exact enclosing bundle.
    /// The bookmark permits signature inspection; it does not authorize opening.
    public static func requirement(for bundle: URL, bookmark: Data) throws -> String {
        guard !bookmark.isEmpty, bookmark.count <= OpenRequest.maximumBookmarkBytes else { throw OpeningError.invalidRequest }
        var stale = false
        let resolved = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
        defer { resolved.stopAccessingSecurityScopedResource() }
        guard !stale, resolved.standardizedFileURL.resolvingSymlinksInPath() == bundle.standardizedFileURL.resolvingSymlinksInPath() else { throw OpeningError.invalidRequest }
        return try requirement(for: resolved)
    }

    /// Derive trust from the bundled peer's actual signature, including ad hoc development hashes.
    /// NSXPC enforces the requirement on messages; no PID-based signature race or unsigned fallback.
    public static func requirement(for bundle: URL) throws -> String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess else { throw OpeningError.serviceUnavailable }
        return try requirementText(for: code)
    }

    private static func requirementText(for code: SecStaticCode) throws -> String {
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(code, [], &requirement) == errSecSuccess, let requirement else { throw OpeningError.serviceUnavailable }
        var text: CFString?
        guard SecRequirementCopyString(requirement, [], &text) == errSecSuccess, let text else { throw OpeningError.serviceUnavailable }
        return text as String
    }
}

@MainActor
public protocol OpeningCancellation: AnyObject { func cancel() }
@MainActor
public protocol FileOpening {
    @discardableResult
    func open(_ source: URL, application: URL?, completion: @escaping (Result<Void, Error>) -> Void) -> OpeningCancellation?
}

@MainActor
public final class XPCFileOpener: FileOpening {
    public static let serviceName = "dev.fileglint.Fileglint.Launcher"
    public init() {}
    public func open(_ source: URL, application: URL?, completion: @escaping (Result<Void, Error>) -> Void) -> OpeningCancellation? {
        do {
            try OpenRequest.validateSource(source)
            let service = Bundle.main.bundleURL.appendingPathComponent("Contents/XPCServices/FileglintLauncher.xpc")
            let requirement = try PeerTrust.requirement(for: service)
            let bookmark = try source.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            let bundleBookmark = try Bundle.main.bundleURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            guard bookmark.count <= OpenRequest.maximumBookmarkBytes, bundleBookmark.count <= OpenRequest.maximumBookmarkBytes else { throw OpeningError.invalidRequest }
            let operation = OpeningOperation(completion: completion)
            operation.start(bookmark, bundleBookmark: bundleBookmark, source: source, application: application, requirement: requirement)
            return operation
        } catch { completion(.failure(error)); return nil }
    }
}

@MainActor
private final class OpeningOperation: OpeningCancellation {
    private var connection: NSXPCConnection?
    private var bootstrap: NSXPCConnection?
    private var completion: ((Result<Void, Error>) -> Void)?
    private var timeout: DispatchWorkItem?
    init(completion: @escaping (Result<Void, Error>) -> Void) { self.completion = completion }
    private func configure(_ connection: NSXPCConnection, requirement: String) {
        connection.setCodeSigningRequirement(requirement)
        connection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async { self?.finish(.failure(OpeningError.serviceUnavailable)) }
        }
        connection.interruptionHandler = connection.invalidationHandler
        connection.resume()
    }
    func start(_ bookmark: Data, bundleBookmark: Data, source: URL, application: URL?, requirement: String) {
        let bootstrap = NSXPCConnection(serviceName: XPCFileOpener.serviceName)
        self.bootstrap = bootstrap
        bootstrap.remoteObjectInterface = NSXPCInterface(with: OpeningBootstrapXPC.self)
        configure(bootstrap, requirement: requirement)
        let timeout = DispatchWorkItem { [weak self] in self?.finish(.failure(OpeningError.timedOut)) }
        self.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
        let proxy = bootstrap.remoteObjectProxyWithErrorHandler { [weak self] _ in
            DispatchQueue.main.async { self?.finish(.failure(OpeningError.serviceUnavailable)) }
        } as? OpeningBootstrapXPC
        proxy?.connect(bundleBookmark) { [weak self] endpoint, message in
            DispatchQueue.main.async {
                guard let self, self.completion != nil else { return }
                guard let endpoint, message == nil else {
                    self.finish(.failure(OpeningError.serviceUnavailable)); return
                }
                let connection = NSXPCConnection(listenerEndpoint: endpoint)
                self.connection = connection
                connection.remoteObjectInterface = NSXPCInterface(with: FileOpeningXPC.self)
                self.configure(connection, requirement: requirement)
                let opener = connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
                    DispatchQueue.main.async { self?.finish(.failure(OpeningError.serviceUnavailable)) }
                } as? FileOpeningXPC
                opener?.openFile(bookmark, sourcePath: source.path, applicationPath: application?.path ?? "") { [weak self] message in
                    DispatchQueue.main.async {
                        if let message {
                            self?.finish(.failure(NSError(domain: "Fileglint.Opening", code: 1, userInfo: [NSLocalizedDescriptionKey: message])))
                        } else { self?.finish(.success(())) }
                    }
                }
            }
        }
    }
    func cancel() {
        completion = nil
        timeout?.cancel()
        connection?.invalidate(); connection = nil
        bootstrap?.invalidate(); bootstrap = nil
    }
    private func finish(_ result: Result<Void, Error>) {
        guard let callback = completion else { return }
        cancel()
        callback(result)
    }
}
