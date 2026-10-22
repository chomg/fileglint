import AppKit
import PreviewOpening

final class Launcher: NSObject, FileOpeningXPC {
    func openFile(_ bookmark: Data, sourcePath: String, applicationPath: String, withReply reply: @escaping (String?) -> Void) {
        do {
            let source = try OpenRequest.resolve(bookmark, sourcePath: sourcePath)
            DispatchQueue.main.async {
                do {
                    let catalog = try ApplicationCatalog.discover(for: source)
                    let application = try OpenRequest.application(applicationPath, in: catalog)
                    let configuration = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.open([source], withApplicationAt: application, configuration: configuration) { _, error in
                        source.stopAccessingSecurityScopedResource()
                        reply(error.map { "Could not open the original file: \($0.localizedDescription)" })
                    }
                } catch {
                    source.stopAccessingSecurityScopedResource()
                    reply(error.localizedDescription)
                }
            }
        } catch { reply(error.localizedDescription) }
    }
}

// Bootstrap can only inspect the exact enclosing extension's signature. Opening
// lives on a separate endpoint whose requirement is enforced before any request.
final class Bootstrap: NSObject, OpeningBootstrapXPC {
    private var session: AuthenticatedListener?
    func connect(_ bundleBookmark: Data, withReply reply: @escaping (NSXPCListenerEndpoint?, String?) -> Void) {
        guard session == nil else { reply(nil, OpeningError.invalidRequest.localizedDescription); return }
        let bundle = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        do {
            let requirement = try PeerTrust.requirement(for: bundle, bookmark: bundleBookmark)
            let session = AuthenticatedListener(requirement: requirement)
            self.session = session
            reply(session.listener.endpoint, nil)
        } catch { reply(nil, error.localizedDescription) }
    }
}

final class AuthenticatedListener: NSObject, NSXPCListenerDelegate {
    let listener = NSXPCListener.anonymous()
    private var connection: NSXPCConnection?
    init(requirement: String) {
        super.init()
        listener.setConnectionCodeSigningRequirement(requirement)
        listener.delegate = self
        listener.resume()
    }
    deinit { listener.invalidate(); connection?.invalidate() }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard self.connection == nil, connection.effectiveUserIdentifier == geteuid() else { return false }
        self.connection = connection
        connection.exportedInterface = NSXPCInterface(with: FileOpeningXPC.self)
        connection.exportedObject = Launcher()
        connection.resume()
        return true
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == geteuid() else { return false }
        connection.exportedInterface = NSXPCInterface(with: OpeningBootstrapXPC.self)
        connection.exportedObject = Bootstrap()
        connection.resume()
        return true
    }
}

let delegate = ListenerDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
