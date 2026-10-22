import Foundation
import Testing
import TOMLKit
import Yams
@testable import PreviewCore

struct CommentPreservationTests {
    func fixture(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Fixtures/" + name), encoding: .utf8)
    }

    func document(_ input: String, _ format: DocumentFormat) throws -> PreviewDocument {
        try PreviewDocument(data: Data(input.utf8), format: format)
    }

    func nodes(_ input: String) throws -> [Node] {
        let parser = try Yams.Parser(yaml: input)
        var result = [Node]()
        while let node = try parser.nextRoot() { result.append(node) }
        return result
    }

    // Line-for-line comparison proves comments stay on the same lines and with
    // the same entries; semantic equality alone would miss all lost comments.
    func expectLinesPreserved(_ input: String, _ output: String, changes: [String: String]) {
        let before = input.components(separatedBy: "\n")
        let after = output.components(separatedBy: "\n")
        #expect(before.count == after.count)
        for (original, formatted) in zip(before, after) {
            #expect(formatted == (changes[original] ?? original))
        }
    }

    @Test func yamlCommentsStreamsTagsAliasesAndScalars() throws {
        let input = try fixture("comments.yaml")
        let preview = try document(input, .yaml)
        let output = try #require(preview.pretty)
        #expect(preview.raw == input)
        #expect(try nodes(input) == nodes(output))
        expectLinesPreserved(input, output, changes: [
            "  items: [1,2,3] # inline array": "  items: [1, 2, 3] # inline array",
            "\"quoted:key\": {first: 1, second: [2,3]} # nested flow collection": "\"quoted:key\": {first: 1, second: [2, 3]} # nested flow collection",
        ])
        #expect(output.contains("copy: *defaults # keep the alias"))
        #expect(output.contains("  keep  =  [1,2]"))
        #expect(try document(output, .yaml).pretty == output)
    }

    @Test func tomlCommentsTablesStringsAndDates() throws {
        let input = try fixture("comments.toml")
        let output = try #require(document(input, .toml).pretty)
        #expect(try TOMLTable(string: input) == TOMLTable(string: output))
        expectLinesPreserved(input, output, changes: [
            "\"name.with.dot\"=\"세계 # value\" # inline name": "\"name.with.dot\" = \"세계 # value\" # inline name",
            "created=2026-10-22T12:00:00Z # date and time": "created = 2026-10-22T12:00:00Z # date and time",
            "basic=\"\"\"": "basic = \"\"\"",
            "literal='''": "literal = '''",
            "four_quotes=\"\"\"value \"\"\"\" # one quote in value": "four_quotes = \"\"\"value \"\"\"\" # one quote in value",
            "five_quotes='''value ''''' # two quotes in value": "five_quotes = '''value ''''' # two quotes in value",
            "items=[1,2,3] # inline array": "items = [1, 2, 3] # inline array",
            "options={enabled=true,label=\"a=b,#c\"} # inline table": "options = {enabled = true, label = \"a=b,#c\"} # inline table",
            "\"dotted\".key='value # literal' # dotted assignment": "\"dotted\".key = 'value # literal' # dotted assignment",
            "values=[": "values = [",
            "name=\"one\" # first name": "name = \"one\" # first name",
            "name=\"two\"": "name = \"two\"",
        ])
        #expect(try document(output, .toml).pretty == output)
    }

    @Test func emptyCommentOnlyAndLineEndings() throws {
        for format in [DocumentFormat.yaml, .toml] {
            for input in ["", "# only comment", "# leading\n# trailing\n", "\u{feff}# 세계 🌍\r\n\r\n# trailing  \r\n"] {
                let preview = try document(input, format)
                #expect(preview.raw == input)
                let expected = input.hasPrefix("\u{feff}") ? String(input.dropFirst()) : input
                #expect(preview.pretty == expected)
            }
        }
        let yaml = "\u{feff}# note\r\n세계: [1,2] # inline\r\n"
        #expect(try document(yaml, .yaml).pretty == "# note\r\n세계: [1, 2] # inline\r\n")
        let toml = "\u{feff}# note\r\nname=\"세계\" # inline\r\n"
        #expect(try document(toml, .toml).pretty == "# note\r\nname = \"세계\" # inline\r\n")
    }

    @Test func yamlOnlyChangesParserIdentifiedGaps() throws {
        for input in [
            "text: it's a 'plain string # real comment\n",
            "text: plain,with:punctuation#inside # actual comment\n",
            "{a:1, b: 2} # a:1 is a key, not a key/value pair\n",
            "{\"세계🌍\":1, 'other':2} # flow\n",
            "# head\n-    first # one\n-    second # two\n",
            "block: |2- # explicit indent\n    # literal\n  less indented\nnext: [1,2] # next\n",
            "? [a,b]\n: [1,2] # complex key\n",
            "plain: first line\n  still  a  scalar # comment\n",
            "---\n# empty document\n---\n[1,2] # second\n",
        ] {
            let output = try #require(document(input, .yaml).pretty)
            #expect(try nodes(input) == nodes(output))
            #expect(input.filter { !$0.isWhitespace } == output.filter { !$0.isWhitespace })
        }
        #expect(try document("{\"世界🌍\":1, 'other':2}", .yaml).pretty == "{\"世界🌍\": 1, 'other': 2}")
    }

    @Test func tomlEscapesAndMultilineQuoteRuns() throws {
        let input = #"""
        escaped="a\"#b\\c" # actual comment
        basic="""a\"""b # inside
        c""" # after basic
        literal='''a # inside
        b''' # after literal
        ending="""last """"" # after five quotes
        """#
        let output = try #require(document(input, .toml).pretty)
        #expect(try TOMLTable(string: input) == TOMLTable(string: output))
        let comments = Syntax.tokens(in: output, format: .toml).filter { $0.kind == .comment }.map { (output as NSString).substring(with: $0.range) }
        #expect(comments == ["# actual comment", "# after basic", "# after literal", "# after five quotes"])
        #expect(output.contains(##"escaped = "a\"#b\\c" # actual comment"##))
        #expect(output.contains("b # inside\n"))
    }

    @Test func malformedAndFormattingBoundariesRetainRaw() throws {
        for (format, valid, invalid) in [(DocumentFormat.yaml, "items: [1,2] # note\n", "# leading\nvalid: 1\n---\nbroken: ["), (.toml, "items=[1,2] # note\n", "# leading\nitems=[")] {
            let malformed = try document(invalid, format)
            #expect(malformed.raw == invalid)
            #expect(malformed.pretty == nil)
            #expect(malformed.formattingError != nil)
            let exact = valid + "#" + String(repeating: "x", count: 131_072 - valid.utf8.count - 1)
            #expect(try document(exact, format).pretty != nil)
            let over = try document(exact + "x", format)
            #expect(over.pretty == nil)
            #expect(over.raw == exact + "x")
            let deep = "items: " + String(repeating: "[", count: 129) + "0" + String(repeating: "]", count: 129)
            let nested = format == .yaml ? deep : deep.replacingOccurrences(of: "items: ", with: "items=")
            #expect(try document(nested, format).pretty == nil)
        }
    }

    @Test func repeatedAliasesStayBoundedAndAreNotExpanded() throws {
        var input = "base: &base [1,2] # base\n"
        var previous = "base"
        for index in 0..<40 {
            let name = "node\(index)"
            input += "\(name): &\(name) [*\(previous),*\(previous)] # layer \(index)\n"
            previous = name
        }
        let output = try #require(document(input, .yaml).pretty)
        #expect(output.contains("base: &base [1, 2] # base"))
        #expect(output.contains("node39: &node39 [*node38,*node38] # layer 39"))
        #expect(output.utf8.count < input.utf8.count + 100)
        #expect(output.components(separatedBy: "\n").count == input.components(separatedBy: "\n").count)
    }

    @Test func readingCommentFixturesNeverWritesSource() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["comments.yaml", "comments.toml"] {
            let bytes = Data(try fixture(name).utf8)
            let url = directory.appendingPathComponent(name)
            try bytes.write(to: url)
            let preview = try PreviewDocument.read(url)
            #expect(preview.pretty != nil)
            #expect(preview.raw == String(decoding: bytes, as: UTF8.self))
            #expect(try Data(contentsOf: url) == bytes)
        }
    }
}
