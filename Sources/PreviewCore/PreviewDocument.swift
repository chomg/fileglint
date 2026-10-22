import Foundation
import TOMLKit
import Yams

public enum DocumentFormat: String, Sendable, CaseIterable {
    case json, yaml, toml

    public init(extension name: String) throws {
        switch name.lowercased() {
        case "json": self = .json
        case "yaml", "yml": self = .yaml
        case "toml": self = .toml
        default: throw PreviewFailure.unsupportedFormat
        }
    }
}

public enum PreviewFailure: LocalizedError {
    case unsupportedFormat, tooLarge, encoding, formattingLimit

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Choose a JSON, YAML or TOML file."
        case .tooLarge: return "This file exceeds the 1 MiB preview limit. Open it in an editor."
        case .formattingLimit: return "Formatting exceeds the complexity limit. Use Raw or open this file in an editor."
        case .encoding: return "This file is not UTF-8 text. Open it in an editor to choose its encoding."
        }
    }
}

public struct PreviewDocument: Sendable {
    public static let byteLimit = 1_048_576
    public let raw: String
    public let format: DocumentFormat
    public private(set) var pretty: String?
    public private(set) var formattingError: String?

    public static func read(_ url: URL) throws -> PreviewDocument {
        let format = try DocumentFormat(extension: url.pathExtension)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        // Read one byte past the cap, never map or load an unbounded file.
        let data = try handle.read(upToCount: byteLimit + 1) ?? Data()
        return try PreviewDocument(data: data, format: format)
    }

    public init(data: Data, format: DocumentFormat) throws {
        guard data.count <= Self.byteLimit else { throw PreviewFailure.tooLarge }
        guard String(data: data, encoding: .utf8) != nil else { throw PreviewFailure.encoding }
        let source = String(decoding: data, as: UTF8.self)
        raw = source
        self.format = format
        let input = source.hasPrefix("\u{feff}") ? String(source.dropFirst()) : source
        do {
            guard data.count <= 131_072 else { throw PreviewFailure.formattingLimit }
            try Formatting.checkComplexity(input, format: format)
            switch format {
            case .json:
                _ = try JSONSerialization.jsonObject(with: Data(input.utf8), options: [.fragmentsAllowed])
                pretty = try Formatting.json(input)
            case .yaml:
                // Nodes preserve YAML scalar tags and support streams without constructing objects or expanding aliases.
                let parser = try Yams.Parser(yaml: input)
                var nodes = [Yams.Node]()
                while let node = try parser.nextRoot() { nodes.append(node) }
                pretty = try Yams.serialize(nodes: nodes, indent: 2, allowUnicode: true, sequenceStyle: .block, mappingStyle: .block)
            case .toml:
                pretty = try TOMLTable(string: input).convert(to: .toml)
            }
            guard (pretty?.utf8.count ?? 0) <= 4_194_304 else { throw PreviewFailure.formattingLimit }
            formattingError = nil
        } catch {
            pretty = nil
            let detail = (error as? TOMLParseError)?.debugDescription ?? error.localizedDescription
            formattingError = "Cannot prettify this \(format.rawValue.uppercased()) file: \(detail)"
        }
    }
}
