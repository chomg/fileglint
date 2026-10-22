import Foundation
import Yams

/// Format original source instead of serializing a data model that has lost comments.
/// Neither path moves lines or rewrites a scalar, comment, tag or anchor.
enum SourceFormatting {
    struct Position: Hashable {
        let line: Int
        let column: Int
    }

    static func yaml(_ input: String) throws -> String {
        let parser = try Yams.Parser(yaml: input)
        var positions = Set<Position>()
        // Yams resolves aliases to nodes at their anchor's position. Visit each
        // container once, rather than recursively expanding repeated aliases.
        var containers = Set<Position>()
        func visit(_ node: Node) {
            guard let mark = node.mark else { return }
            // Implicit nulls have no source token. Their mark can point into the
            // gap before a comment; treating it as a boundary adds space on
            // every formatting pass. Explicit empty quoted strings have tokens.
            if case .scalar(let scalar) = node, scalar.style == .plain && scalar.string.isEmpty { return }
            let position = Position(line: mark.line, column: mark.column)
            positions.insert(position)
            switch node {
            case .mapping(let mapping):
                guard containers.insert(position).inserted else { return }
                for (key, value) in mapping { visit(key); visit(value) }
            case .sequence(let sequence):
                guard containers.insert(position).inserted else { return }
                for value in sequence { visit(value) }
            case .scalar, .alias: break
            }
        }
        // Consume the whole stream: an error in a later document must fail too.
        while let node = try parser.nextRoot() { visit(node) }

        let bytes = Array(input.utf8)
        var edits = [Int: Range<Int>]()
        var offset = 0
        var line = 1
        var column = 1
        var previousWasCR = false
        // libyaml columns count Unicode scalars, not UTF-8 bytes or UTF-16 units.
        for scalar in input.unicodeScalars {
            if positions.contains(Position(line: line, column: column)) {
                var start = offset
                while start > 0 && horizontal(bytes[start - 1]) { start -= 1 }
                if start > 0 && [UInt8(58), 44, 45].contains(bytes[start - 1]) {
                    // Only same-line whitespace immediately before a parsed node.
                    // In particular, never change indentation or spaces in values.
                    edits[start] = start..<offset
                }
            }
            offset += scalar.utf8.count
            if scalar == "\r" || scalar == "\u{85}" || scalar == "\u{2028}" || scalar == "\u{2029}" {
                line += 1; column = 1
            } else if scalar == "\n" {
                if !previousWasCR { line += 1 }
                column = 1
            } else { column += 1 }
            previousWasCR = scalar == "\r"
        }
        return String(decoding: applying(edits.values.map { ($0, [UInt8(32)]) }, to: bytes), as: UTF8.self)
    }

    /// Strings and comments are opaque ranges. This lexer does not validate TOML;
    /// TOMLKit validates before formatting. Keep quote runs of four/five together
    /// at the end of multiline strings, and respect escapes in basic strings.
    static func tomlTokens(_ input: String) -> [SyntaxToken] {
        let source = Array(input.utf16)
        var tokens = [SyntaxToken]()
        var index = 0
        while index < source.count {
            let start = index
            let character = source[index]
            if character == 35 {
                while index < source.count && source[index] != 10 && source[index] != 13 { index += 1 }
                tokens.append(SyntaxToken(range: NSRange(start..<index), kind: .comment))
            } else if character == 34 || character == 39 {
                let multiline = index + 2 < source.count && source[index + 1] == character && source[index + 2] == character
                index += multiline ? 3 : 1
                while index < source.count {
                    if character == 34 && source[index] == 92 {
                        index = min(index + 2, source.count)
                    } else if source[index] == character {
                        var end = index + 1
                        if multiline {
                            while end < source.count && source[end] == character { end += 1 }
                        }
                        let closes = !multiline || end - index >= 3
                        index = end
                        if closes { break }
                    } else { index += 1 }
                }
                tokens.append(SyntaxToken(range: NSRange(start..<index), kind: .string))
            } else { index += 1 }
        }
        return tokens
    }

    static func toml(_ input: String) -> String {
        let source = Array(input.utf16)
        let tokens = tomlTokens(input)
        var edits = [(Range<Int>, [UInt16])]()
        var tokenIndex = 0
        var index = 0
        while index < source.count {
            if tokenIndex < tokens.count && tokens[tokenIndex].range.location == index {
                index = NSMaxRange(tokens[tokenIndex].range)
                tokenIndex += 1
                continue
            }
            if source[index] == 61 { // Spaces around assignment, also inside inline tables.
                var start = index
                while start > 0 && horizontal(source[start - 1]) { start -= 1 }
                var end = index + 1
                while end < source.count && horizontal(source[end]) { end += 1 }
                edits.append((start..<end, [32, 61, 32]))
                index = end
            } else if source[index] == 44 { // Space after a comma, without moving comments/lines.
                var end = index + 1
                while end < source.count && horizontal(source[end]) { end += 1 }
                if end < source.count && source[end] != 10 && source[end] != 13 && source[end] != 93 {
                    edits.append(((index + 1)..<end, [32]))
                }
                index = end
            } else { index += 1 }
        }
        return String(decoding: applying(edits, to: source), as: UTF16.self)
    }

    private static func horizontal<T: BinaryInteger>(_ value: T) -> Bool { value == 32 || value == 9 }

    private static func applying<T>(_ edits: [(Range<Int>, [T])], to source: [T]) -> [T] {
        var output = [T]()
        var offset = 0
        for (range, replacement) in edits.sorted(by: { $0.0.lowerBound < $1.0.lowerBound }) {
            output.append(contentsOf: source[offset..<range.lowerBound])
            output.append(contentsOf: replacement)
            offset = range.upperBound
        }
        output.append(contentsOf: source[offset...])
        return output
    }

}
