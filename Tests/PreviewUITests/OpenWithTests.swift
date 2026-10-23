import AppKit
import Testing
import PreviewCore
import PreviewOpening
@testable import PreviewUI

@MainActor
private final class Discovery: ApplicationDiscovering {
    var requests: [(URL, (Result<ApplicationCatalog, Error>) -> Void)] = []
    func discover(for source: URL, completion: @escaping (Result<ApplicationCatalog, Error>) -> Void) { requests.append((source, completion)) }
    func reply(_ index: Int, _ catalog: ApplicationCatalog) { requests[index].1(.success(catalog)) }
}
@MainActor
private final class Opener: FileOpening {
    final class Cancellation: OpeningCancellation { var cancelled = false; func cancel() { cancelled = true } }
    var requests: [(source: URL, application: URL?, completion: (Result<Void, Error>) -> Void, cancellation: Cancellation)] = []
    func open(_ source: URL, application: URL?, completion: @escaping (Result<Void, Error>) -> Void) -> OpeningCancellation? {
        let cancellation = Cancellation()
        requests.append((source, application, completion, cancellation))
        return cancellation
    }
}

extension AppKitTests {
@Suite(.serialized) @MainActor
struct OpenWithTests {
    init() { _ = NSApplication.shared }
    let fileA = URL(fileURLWithPath: "/tmp/original.json")
    let fileB = URL(fileURLWithPath: "/tmp/next.toml")
    let first = ApplicationChoice(url: URL(fileURLWithPath: "/Applications/First.app"), name: "First")
    let second = ApplicationChoice(url: URL(fileURLWithPath: "/Applications/Second.app"), name: "Second")
    var catalog: ApplicationCatalog { .init(applications: [second, first], defaultURL: first.url) }

    @Test func arrowRefreshesMenuWithoutOpeningAndSelectionUsesOriginalURL() throws {
        let discovery = Discovery(), opener = Opener()
        let control = OpenWithController(discovery: discovery, opener: opener)
        var menu: NSMenu?
        control.presentMenu = { shown, _ in menu = shown }
        control.setSource(fileA); discovery.reply(0, catalog)
        #expect(control.mainButton.title == "Open with First")
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            control.buttons.appearance = NSAppearance(named: appearance)
            control.menuButton.performClick(nil)
            #expect(discovery.requests.count > 1)
            discovery.reply(discovery.requests.count - 1, catalog)
            #expect(opener.requests.isEmpty)
            let items = try #require(menu).items
            #expect(items.map(\.title) == ["First (Default)", "Second"])
            #expect(items[0].state == .on)
        }
        let item = try #require(menu).items[1]
        #expect(NSApp.sendAction(item.action!, to: item.target, from: item))
        discovery.reply(discovery.requests.count - 1, catalog)
        let request = try #require(opener.requests.first)
        #expect(request.source == fileA)
        #expect(request.application == second.url)
        #expect(!control.mainButton.isEnabled && !control.menuButton.isEnabled)
        request.completion(.success(()))
        #expect(control.mainButton.isEnabled)
        #expect(control.status.isHidden)
    }

    @Test func mainActionRequeriesChangedDefaultWithoutRememberingLastChoice() throws {
        let discovery = Discovery(), opener = Opener()
        let control = OpenWithController(discovery: discovery, opener: opener)
        control.setSource(fileA); discovery.reply(0, catalog)
        control.mainButton.performClick(nil)
        let changed = ApplicationCatalog(applications: [first, second], defaultURL: second.url)
        discovery.reply(1, changed)
        #expect(control.mainButton.title == "Open with Second")
        #expect(try #require(opener.requests.first).application == nil)
        opener.requests[0].completion(.success(()))
        control.setSource(fileA); discovery.reply(2, catalog)
        #expect(control.mainButton.title == "Open with First")
    }

    @Test func noDefaultStillAllowsAlternativesAndEmptyListExplainsWhy() {
        let discovery = Discovery(), opener = Opener()
        let control = OpenWithController(discovery: discovery, opener: opener)
        control.setSource(fileA)
        discovery.reply(0, .init(applications: [second], defaultURL: nil))
        #expect(!control.mainButton.isEnabled && control.menuButton.isEnabled)
        #expect(control.status.stringValue.contains("No default"))
        var menu: NSMenu?
        control.presentMenu = { shown, _ in menu = shown }
        control.menuButton.performClick(nil)
        discovery.reply(1, .init(applications: [], defaultURL: nil))
        #expect(menu?.items.count == 1 && menu?.items.first?.isEnabled == false)
        #expect(control.status.stringValue.contains("No compatible"))
        #expect(opener.requests.isEmpty)
    }

    @Test func lateQueriesAndOldMenuActionsCannotOpenNewerOrPreviousDocuments() throws {
        let discovery = Discovery(), opener = Opener()
        let control = OpenWithController(discovery: discovery, opener: opener)
        var menu: NSMenu?
        control.presentMenu = { shown, _ in menu = shown }
        control.setSource(fileA); discovery.reply(0, catalog)
        control.menuButton.performClick(nil); discovery.reply(1, catalog)
        let stale = try #require(menu).items[1]
        control.mainButton.performClick(nil) // delayed discovery for A
        control.setSource(fileB)
        discovery.reply(3, .init(applications: [second], defaultURL: second.url))
        discovery.reply(2, catalog) // A result arrives after B
        #expect(control.mainButton.title == "Open with Second")
        #expect(NSApp.sendAction(stale.action!, to: stale.target, from: stale))
        #expect(discovery.requests.count == 4)
        #expect(opener.requests.isEmpty)
    }

    @Test func removedAppsMissingFilesAndLaunchFailuresAreVisible() throws {
        let discovery = Discovery(), opener = Opener()
        let control = OpenWithController(discovery: discovery, opener: opener)
        var menu: NSMenu?
        control.presentMenu = { shown, _ in menu = shown }
        control.setSource(fileA); discovery.reply(0, catalog)
        control.menuButton.performClick(nil); discovery.reply(1, catalog)
        let item = try #require(menu).items[1]
        #expect(NSApp.sendAction(item.action!, to: item.target, from: item))
        discovery.reply(2, .init(applications: [first], defaultURL: first.url))
        #expect(opener.requests.isEmpty)
        #expect(control.status.stringValue.contains("no longer available"))
        control.mainButton.performClick(nil); discovery.reply(3, catalog)
        opener.requests[0].completion(.failure(OpeningError.timedOut))
        #expect(control.status.stringValue.contains("timed out"))
        control.menuButton.performClick(nil)
        discovery.requests[4].1(.failure(OpeningError.unavailableFile))
        #expect(!control.mainButton.isEnabled)
        #expect(control.status.stringValue.contains("unavailable"))
    }

    @Test func navigationCancelsOperationAndIgnoresLateLaunchCompletion() {
        let discovery = Discovery(), opener = Opener()
        let control = OpenWithController(discovery: discovery, opener: opener)
        control.setSource(fileA); discovery.reply(0, catalog)
        control.mainButton.performClick(nil); discovery.reply(1, catalog)
        control.setSource(fileB); discovery.reply(2, catalog)
        #expect(opener.requests[0].cancellation.cancelled)
        opener.requests[0].completion(.failure(OpeningError.timedOut))
        #expect(control.status.isHidden)
        #expect(control.mainButton.isEnabled)
    }

    @Test func delayedDiscoveryTimesOutAndLateResultIsIgnored() async throws {
        let discovery = Discovery()
        let control = OpenWithController(discovery: discovery, opener: Opener())
        control.queryTimeout = 0.01
        control.setSource(fileA)
        try await Task.sleep(for: .milliseconds(50))
        #expect(control.status.stringValue.contains("timed out"))
        discovery.reply(0, catalog)
        #expect(!control.mainButton.isEnabled)
        #expect(control.status.stringValue.contains("timed out"))
    }

    @Test func syntheticSamplesHideOpeningAndParseErrorsKeepItIndependent() throws {
        let controller = PreviewViewController()
        controller.display(Result { try PreviewDocument(data: Data("{".utf8), format: .json) })
        #expect(controller.opening.buttons.isHidden)
        controller.display(Result { try PreviewDocument(data: Data("{".utf8), format: .json) }, sourceURL: fileA)
        #expect(!controller.opening.buttons.isHidden)
        #expect(controller.status.stringValue.contains("Cannot prettify"))
        #expect(!controller.mode.isEnabled(forSegment: 1))
        controller.display(Result { try PreviewDocument(data: Data("{}".utf8), format: .json) })
        #expect(controller.opening.buttons.isHidden)
        #expect(controller.opening.status.isHidden)
    }
}
}
