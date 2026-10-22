import AppKit

public struct ApplicationChoice: Equatable, Sendable {
    public let url: URL
    public let name: String
    public init(url: URL, name: String) {
        self.url = url.standardizedFileURL.resolvingSymlinksInPath()
        self.name = name
    }
}

public struct ApplicationCatalog: Sendable {
    public let applications: [ApplicationChoice]
    public let defaultURL: URL?

    public init(applications: [ApplicationChoice], defaultURL: URL?) {
        let canonical = defaultURL?.standardizedFileURL.resolvingSymlinksInPath()
        var unique: [URL: ApplicationChoice] = [:]
        for app in applications { unique[app.url] = unique[app.url] ?? app }
        let defaultChoice = canonical.flatMap { unique[$0] == nil ? nil : $0 }
        self.defaultURL = defaultChoice
        self.applications = unique.values.sorted {
            if ($0.url == defaultChoice) != ($1.url == defaultChoice) { return $0.url == defaultChoice }
            let comparison = $0.name.compare($1.name, options: [.caseInsensitive, .numeric], locale: Locale(identifier: "en_US_POSIX"))
            return comparison == .orderedSame ? $0.url.path < $1.url.path : comparison == .orderedAscending
        }
    }

    public var defaultApplication: ApplicationChoice? { applications.first { $0.url == defaultURL } }

    public func label(for app: ApplicationChoice) -> String {
        let ambiguous = applications.filter { $0.name.caseInsensitiveCompare(app.name) == .orderedSame }.count > 1
        return app.name + (ambiguous ? " — \(app.url.path)" : "")
    }

    public static func discover(for source: URL) throws -> ApplicationCatalog {
        try OpenRequest.validateSource(source)
        let workspace = NSWorkspace.shared
        let currentDefault = workspace.urlForApplication(toOpen: source)
        var urls = workspace.urlsForApplications(toOpen: source)
        if let currentDefault { urls.insert(currentDefault, at: 0) }
        let apps = urls.compactMap { url -> ApplicationChoice? in
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let name = FileManager.default.displayName(atPath: url.path)
            return ApplicationChoice(url: url, name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name)
        }
        return .init(applications: apps, defaultURL: currentDefault)
    }
}

@MainActor
public protocol ApplicationDiscovering {
    func discover(for source: URL, completion: @escaping (Result<ApplicationCatalog, Error>) -> Void)
}

@MainActor
public final class WorkspaceApplicationDiscovery: ApplicationDiscovering {
    public init() {}
    public func discover(for source: URL, completion: @escaping (Result<ApplicationCatalog, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try ApplicationCatalog.discover(for: source) }
            DispatchQueue.main.async { completion(result) }
        }
    }
}
