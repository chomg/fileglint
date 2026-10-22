import Foundation

public enum OpeningError: LocalizedError {
    case unavailableFile, unsupportedFile, unavailableApplication, noDefault, invalidRequest, serviceUnavailable, timedOut
    public var errorDescription: String? {
        switch self {
        case .unavailableFile: return "The original file is unavailable. Reopen its preview in Finder."
        case .unsupportedFile: return "Opening is available for JSON, YAML and TOML files."
        case .unavailableApplication: return "This application is no longer available for the file. Choose another application."
        case .noDefault: return "No default application is set. Choose an application using the arrow."
        case .invalidRequest: return "The file changed or moved. Reopen its preview before opening it."
        case .serviceUnavailable: return "The file-opening service is unavailable. Rebuild or reopen Fileglint and try again."
        case .timedOut: return "Opening the file timed out. Try again or use Finder’s Open With menu."
        }
    }
}

public enum OpenRequest {
    public static let maximumBookmarkBytes = 65_536
    public static let maximumPathBytes = 32_768
    public static func validateSource(_ url: URL) throws {
        guard url.isFileURL, url.path.utf8.count <= maximumPathBytes,
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              FileManager.default.isReadableFile(atPath: url.path) else { throw OpeningError.unavailableFile }
        guard ["json", "yaml", "yml", "toml"].contains(url.pathExtension.lowercased()) else { throw OpeningError.unsupportedFile }
    }

    /// The ephemeral bookmark conveys only the source's existing access to the helper.
    /// Caller owns the resolved URL's scope and must release it after the launch callback.
    public static func resolve(_ bookmark: Data, sourcePath: String) throws -> URL {
        guard !bookmark.isEmpty, bookmark.count <= maximumBookmarkBytes,
              !sourcePath.isEmpty, sourcePath.utf8.count <= maximumPathBytes,
              sourcePath.hasPrefix("/"), !sourcePath.contains("\0") else { throw OpeningError.invalidRequest }
        var stale = false
        let resolved = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
        do {
            guard !stale, resolved.standardizedFileURL == URL(fileURLWithPath: sourcePath).standardizedFileURL else { throw OpeningError.invalidRequest }
            try validateSource(resolved)
            return resolved
        } catch {
            resolved.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    public static func application(_ requestedPath: String, in catalog: ApplicationCatalog) throws -> URL {
        guard requestedPath.utf8.count <= maximumPathBytes, !requestedPath.contains("\0") else { throw OpeningError.invalidRequest }
        if requestedPath.isEmpty {
            guard let url = catalog.defaultURL else { throw OpeningError.noDefault }
            return url
        }
        guard requestedPath.hasPrefix("/") else { throw OpeningError.invalidRequest }
        let url = URL(fileURLWithPath: requestedPath).standardizedFileURL.resolvingSymlinksInPath()
        guard catalog.applications.contains(where: { $0.url == url }) else { throw OpeningError.unavailableApplication }
        return url
    }
}
