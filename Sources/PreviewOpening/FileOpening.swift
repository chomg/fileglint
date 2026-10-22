import Foundation
import Security

@objc(FileglintFileOpening)
public protocol FileOpeningXPC {
    func openFile(_ bookmark: Data, sourcePath: String, applicationPath: String, withReply reply: @escaping (String?) -> Void)
}

public enum PeerTrust {
    /// Derive trust from the bundled peer's actual signature, including ad hoc development hashes.
    /// NSXPC enforces the requirement on messages; no PID-based signature race or unsigned fallback.
    public static func requirement(for bundle: URL) throws -> String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess else { throw OpeningError.serviceUnavailable }
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
            guard bookmark.count <= OpenRequest.maximumBookmarkBytes else { throw OpeningError.invalidRequest }
            let operation = OpeningOperation(completion: completion)
            operation.start(bookmark, source: source, application: application, requirement: requirement)
            return operation
        } catch { completion(.failure(error)); return nil }
    }
}

@MainActor
private final class OpeningOperation: OpeningCancellation {
    private var connection: NSXPCConnection?
    private var completion: ((Result<Void, Error>) -> Void)?
    private var timeout: DispatchWorkItem?
    init(completion: @escaping (Result<Void, Error>) -> Void) { self.completion = completion }
    func start(_ bookmark: Data, source: URL, application: URL?, requirement: String) {
        let connection = NSXPCConnection(serviceName: XPCFileOpener.serviceName)
        self.connection = connection
        connection.remoteObjectInterface = NSXPCInterface(with: FileOpeningXPC.self)
        connection.setCodeSigningRequirement(requirement)
        connection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async { self?.finish(.failure(OpeningError.serviceUnavailable)) }
        }
        connection.interruptionHandler = connection.invalidationHandler
        connection.resume()
        let timeout = DispatchWorkItem { [weak self] in self?.finish(.failure(OpeningError.timedOut)) }
        self.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
        let proxy = connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
            DispatchQueue.main.async { self?.finish(.failure(OpeningError.serviceUnavailable)) }
        } as? FileOpeningXPC
        proxy?.openFile(bookmark, sourcePath: source.path, applicationPath: application?.path ?? "") { [weak self] message in
            DispatchQueue.main.async {
                if let message {
                    self?.finish(.failure(NSError(domain: "Fileglint.Opening", code: 1, userInfo: [NSLocalizedDescriptionKey: message])))
                } else { self?.finish(.success(())) }
            }
        }
    }
    func cancel() { completion = nil; timeout?.cancel(); connection?.invalidate(); connection = nil }
    private func finish(_ result: Result<Void, Error>) {
        guard let callback = completion else { return }
        cancel()
        callback(result)
    }
}
