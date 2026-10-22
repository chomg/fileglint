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

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == geteuid() else { return false }
        connection.exportedInterface = NSXPCInterface(with: FileOpeningXPC.self)
        connection.exportedObject = Launcher()
        connection.resume()
        return true
    }
}

// The service is nested in this exact preview extension; use its designated signature.
let extensionBundle = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
guard let requirement = try? PeerTrust.requirement(for: extensionBundle) else { exit(EXIT_FAILURE) }
let delegate = ListenerDelegate()
let listener = NSXPCListener.service()
listener.setConnectionCodeSigningRequirement(requirement)
listener.delegate = delegate
listener.resume()
