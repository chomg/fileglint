import Foundation

// Exercise the real sandboxed service and both signature checks. A deliberately
// unregistered app must reach server validation without launching anything.
let opener = MainActor.assumeIsolated { XPCFileOpener() }
var operation: OpeningCancellation?
MainActor.assumeIsolated {
    let source = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/source.json")
    operation = opener.open(source, application: URL(fileURLWithPath: "/Fileglint-Not-Installed.app")) { result in
        if case .failure(let error) = result,
           (error as NSError).domain == "Fileglint.Opening",
           error.localizedDescription == OpeningError.unavailableApplication.localizedDescription {
            print("Sandboxed launcher round trip passed: authenticated request rejected the unregistered application.")
            exit(EXIT_SUCCESS)
        }
        fputs("Sandboxed launcher round trip failed: \(result)\n", stderr)
        exit(EXIT_FAILURE)
    }
}
RunLoop.main.run()
