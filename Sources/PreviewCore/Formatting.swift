import Foundation

/// Whitespace-only JSON formatting after parser validation preserves large numbers,
/// duplicate keys and escape spelling. This is not a replacement JSON parser.
enum Formatting {
    static func checkComplexity(_ input: String, format: DocumentFormat) throws {
        let ns = input as NSString
        let ignored = Syntax.tokens(in: input, format: format).filter { $0.kind == .string || $0.kind == .comment }
        // Replace complete tokens with equal-length whitespace so structural characters inside them are ignored.
        let mutable = NSMutableString(string: input)
        for token in ignored.reversed() {
            mutable.replaceCharacters(in: token.range, with: String(repeating: " ", count: token.range.length))
        }
        let masked = mutable as String
        var depth = 0
        for character in masked {
            if character == "[" || character == "{" { depth += 1 }
            if character == "]" || character == "}" { depth -= 1 }
            if depth > 128 { throw PreviewFailure.formattingLimit }
        }
        if format == .yaml {
            for line in ns.components(separatedBy: .newlines) where line.prefix(while: { $0 == " " }).count > 128 {
                throw PreviewFailure.formattingLimit
            }
        }
    }

    static func json(_ input: String) throws -> String {
        let source = Array(input.utf8)
        var output = [UInt8]()
        var depth = 0
        var quoted = false
        var escaped = false
        var previous: UInt8 = 0
        func newline() { output += [10] + Array(repeating: 32, count: depth * 2) }
        for byte in source {
            if quoted {
                output.append(byte)
                if escaped { escaped = false }
                else if byte == 92 { escaped = true }
                else if byte == 34 { quoted = false }
            } else {
                switch byte {
                case 34:
                    quoted = true
                    output.append(byte)
                case 123, 91:
                    output.append(byte)
                    depth += 1
                    newline()
                case 125, 93:
                    depth -= 1
                    if previous == 123 || previous == 91 {
                        while output.last == 32 || output.last == 10 { output.removeLast() }
                    } else { newline() }
                    output.append(byte)
                case 44:
                    output.append(byte)
                    newline()
                case 58: output += [58, 32]
                case 9, 10, 13, 32: continue
                default: output.append(byte)
                }
            }
            previous = byte
            if output.count > 4_194_304 { throw PreviewFailure.formattingLimit }
        }
        return String(decoding: output, as: UTF8.self)
    }
}
