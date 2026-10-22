import Foundation
import Security
import Testing
@testable import PreviewOpening

struct ApplicationOpeningTests {
    private func app(_ path: String, _ name: String) -> ApplicationChoice { .init(url: URL(fileURLWithPath: path), name: name) }

    @Test func catalogDeduplicatesAndSortsDefaultThenNamesAndPaths() {
        let a = app("/Applications/Z.app", "Zed")
        let b = app("/Applications/B.app", "Editor")
        let c = app("/Other/Editor.app", "Editor")
        let apps = [c, b, a, b]
        let catalog = ApplicationCatalog(applications: apps, defaultURL: a.url)
        #expect(catalog.applications.map(\.url) == [a.url, b.url, c.url])
        #expect(ApplicationCatalog(applications: apps.reversed(), defaultURL: a.url).applications == catalog.applications)
        #expect(catalog.label(for: b).contains(b.url.path))
        #expect(catalog.label(for: c) != catalog.label(for: b))
        #expect(catalog.label(for: a) == "Zed")
    }

    @Test func absentDefaultDoesNotRemoveAlternatives() throws {
        let app = app("/Applications/Editor.app", "Editor")
        let catalog = ApplicationCatalog(applications: [app], defaultURL: URL(fileURLWithPath: "/Removed.app"))
        #expect(catalog.defaultApplication == nil)
        #expect(try OpenRequest.application(app.url.path, in: catalog) == app.url)
        #expect(throws: (any Error).self) { try OpenRequest.application("", in: catalog) }
        #expect(ApplicationCatalog(applications: [], defaultURL: nil).applications.isEmpty)
    }

    @Test func selectedAppMustStillBeRegistered() throws {
        let a = app("/Applications/Editor.app", "Editor")
        let catalog = ApplicationCatalog(applications: [a], defaultURL: a.url)
        #expect(try OpenRequest.application("", in: catalog) == a.url)
        for invalid in ["/Removed.app", "relative.app", "https://example.com/app", String(repeating: "x", count: OpenRequest.maximumPathBytes + 1), "/bad\0.app"] {
            #expect(throws: (any Error).self) { try OpenRequest.application(invalid, in: catalog) }
        }
    }

    @Test func bookmarkOpensOnlyItsOriginalSupportedFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("세계.json")
        let other = directory.appendingPathComponent("other.json")
        let bytes = Data("{}".utf8)
        try bytes.write(to: source); try bytes.write(to: other)
        let bookmark = try source.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let resolved = try OpenRequest.resolve(bookmark, sourcePath: source.path)
        defer { resolved.stopAccessingSecurityScopedResource() }
        #expect(resolved.standardizedFileURL == source.standardizedFileURL)
        #expect(throws: (any Error).self) { try OpenRequest.resolve(bookmark, sourcePath: other.path) }
        #expect(try Data(contentsOf: source) == bytes)
        let unsupported = directory.appendingPathComponent("script.sh")
        try bytes.write(to: unsupported)
        for invalid in [directory, unsupported, directory.appendingPathComponent("missing.yaml"), URL(string: "https://example.com/a.json")!] {
            #expect(throws: (any Error).self) { try OpenRequest.validateSource(invalid) }
        }
        for bad in [Data(), Data([1,2,3]), Data(repeating: 0, count: OpenRequest.maximumBookmarkBytes + 1)] {
            #expect(throws: (any Error).self) { try OpenRequest.resolve(bad, sourcePath: source.path) }
        }
        try FileManager.default.removeItem(at: source)
        #expect(throws: (any Error).self) { try OpenRequest.resolve(bookmark, sourcePath: source.path) }
    }

    @Test func signedPeerRequirementRejectsDifferentOrUnsignedCode() throws {
        let app = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        let text = try PeerTrust.requirement(for: app)
        var requirement: SecRequirement?
        #expect(SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess)
        let required = try #require(requirement)
        for (path, matches) in [(app.path, true), ("/System/Applications/Calculator.app", false)] {
            var code: SecStaticCode?
            #expect(SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess)
            let status = SecStaticCodeCheckValidity(try #require(code), [], required)
            #expect((status == errSecSuccess) == matches)
        }
        #expect(throws: (any Error).self) { try PeerTrust.requirement(for: URL(fileURLWithPath: "/not-a-signed-peer")) }
    }
}
