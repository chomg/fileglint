import Foundation

public enum TokenKind: Sendable { case string, number, keyword, comment, key }
public struct SyntaxToken: Sendable {
    public let range: NSRange
    public let kind: TokenKind
}

/// Lexical color hints only; parsers, not highlighting, decide validity.
public enum Syntax {
    public static func tokens(in text: String, format: DocumentFormat) -> [SyntaxToken] {
        let pattern = #"(?<string>\"\"\"[\s\S]*?\"\"\"|'''[\s\S]*?'''|\"(?:\\.|[^\"\\])*\"|'(?:''|[^'])*')|(?<comment>#[^\r\n]*)|(?<number>(?<![\w])[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)|(?<keyword>\b(?:true|false|null|yes|no|inf|nan)\b)|(?<key>[\p{L}_][\p{L}\p{N}_.-]*(?=\s*[:=]))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            for (name, kind) in [("string", TokenKind.string), ("comment", .comment), ("number", .number), ("keyword", .keyword), ("key", .key)] {
                let found = match.range(withName: name)
                if found.location != NSNotFound {
                    if kind == .comment && format == .json { return nil }
                    return SyntaxToken(range: found, kind: kind)
                }
            }
            return nil
        }
    }
}
