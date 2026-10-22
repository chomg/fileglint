import Foundation
import Testing
import TOMLKit
import Yams
@testable import PreviewCore

struct PreviewDocumentTests {
    func strictNodes(_ source: String) throws -> [Node] {
        var stream = try compose_all(yaml: source)
        var nodes = [Node]()
        while let node = stream.next() { nodes.append(node) }
        if let error = stream.error { throw error }
        return nodes
    }

    func document(_ source: String, _ format: DocumentFormat) throws -> PreviewDocument {
        try PreviewDocument(data: Data(source.utf8), format: format)
    }

    @Test func testJSONRoundTripAndRawUnicode() throws {
        let source = #"{"世界":"🌍","values":[true,null,3.5],"url":"https://example.com"}"#
        let preview = try document(source, .json)
        #expect(preview.raw == source)
        let pretty = try #require(preview.pretty)
        #expect(pretty.contains("\n"))
        let original = try JSONSerialization.jsonObject(with: Data(source.utf8)) as? NSDictionary
        let formatted = try JSONSerialization.jsonObject(with: Data(pretty.utf8)) as? NSDictionary
        #expect(original == formatted)
    }

    @Test func testJSONScalarsAndBOM() throws {
        for source in ["null", "true", "42", #""hello""#] {
            #expect(try document(source, .json).pretty != nil)
        }
        let preview = try document("\u{feff}{\"a\":1}", .json)
        #expect(preview.raw.hasPrefix("\u{feff}"))
        #expect(preview.pretty != nil)
    }

    @Test func testYAMLStreamAndScalarSemantics() throws {
        let source = "# note\nname: 世界\nitems: [1, 2]\n---\ndate: 2026-10-21\ntruth: true\n"
        let preview = try document(source, .yaml)
        #expect(preview.raw == source)
        let output = try #require(preview.pretty)
        #expect(try strictNodes(output) == strictNodes(source))
        #expect(try document("", .yaml).pretty != nil)
        #expect(try document("plain scalar", .yaml).pretty != nil)
    }

    @Test func testTOMLTablesArraysDatesAndStrings() throws {
        let source = "# note\nname=\"🌍\"\n[preview]\nitems=[1,2,3]\ncreated=2026-10-21T12:00:00Z\n"
        let preview = try document(source, .toml)
        #expect(preview.raw == source)
        let output = try #require(preview.pretty)
        #expect(try TOMLTable(string: source) == TOMLTable(string: output))
        #expect(try document("", .toml).pretty != nil)
    }

    @Test func testMalformedInputRetainsRaw() throws {
        for (format, source) in [(DocumentFormat.json, "{\"a\":"), (.yaml, "items: ["), (.yaml, "valid: true\n---\nbroken: ["), (.toml, "x = [")] {
            let preview = try document(source, format)
            #expect(preview.raw == source)
            #expect(preview.pretty == nil)
            #expect(preview.formattingError != nil)
        }
        #expect(try document("", .json).pretty == nil)
    }

    @Test func testReadIsBoundedAndDoesNotWrite() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("sample.JSON")
        let data = Data(#"{"n":1}"#.utf8)
        try data.write(to: url)
        #expect(try PreviewDocument.read(url).pretty != nil)
        #expect(try Data(contentsOf: url) == data)
        try Data(repeating: 32, count: PreviewDocument.byteLimit + 1).write(to: url)
        #expect(throws: (any Error).self) { _ = try PreviewDocument.read(url) }
        #expect(throws: (any Error).self) { _ = try PreviewDocument.read(folder.appendingPathComponent("missing.json")) }
        #expect(throws: (any Error).self) { _ = try DocumentFormat(extension: "txt") }
        #expect(try DocumentFormat(extension: "yml") == .yaml)
    }

    @Test func testByteAndEncodingBoundaries() throws {
        #expect(throws: (any Error).self) { _ = try PreviewDocument(data: Data([0xff]), format: .yaml) }
        #expect(throws: (any Error).self) { _ = try PreviewDocument(data: Data(repeating: 32, count: PreviewDocument.byteLimit + 1), format: .yaml) }
        #expect(try PreviewDocument(data: Data(repeating: 32, count: PreviewDocument.byteLimit), format: .yaml).raw.utf8.count == PreviewDocument.byteLimit)
    }

    @Test func testJSONPreservesNumericLexemesAndEscapes() throws {
        let source = #"{"big":123456789012345678901234567890,"float":1.234567890123456789,"repeat":1,"repeat":2,"escaped":"a\\b\"c","empty":[{},[]]}"#
        let output = try #require(document(source, .json).pretty)
        #expect(output.contains("123456789012345678901234567890"))
        #expect(output.contains("1.234567890123456789"))
        #expect(output.components(separatedBy: "repeat").count == 3)
        #expect(output.contains(#"a\\b\"c"#))
        #expect(throws: Never.self) { _ = try JSONSerialization.jsonObject(with: Data(output.utf8)) }
    }

    @Test func testFormattingLimitsRetainRawAndYAMLAliases() throws {
        let nested = String(repeating: "[", count: 129) + "0" + String(repeating: "]", count: 129)
        let preview = try document(nested, .json)
        #expect(preview.raw == nested)
        #expect(preview.pretty == nil)
        #expect(preview.formattingError?.contains("complexity") == true)
        let large = String(repeating: " ", count: 131_073)
        #expect(try document(large, .yaml).pretty == nil)
        let aliases = "base: &base [one, two]\ncopy: *base\n"
        let aliasPreview = try document(aliases, .yaml)
        #expect(aliasPreview.raw == aliases)
        let output = try #require(aliasPreview.pretty)
        #expect(try strictNodes(output) == strictNodes(aliases))
    }

    @Test func testSyntaxUnicodeRangesAndStringCommentBoundaries() {
        let source = "name: \"세계 # still string\" # comment\nnumber: 42\n"
        let tokens = Syntax.tokens(in: source, format: .yaml)
        #expect(tokens.contains { $0.kind == .comment })
        #expect(tokens.contains { $0.kind == .number })
        #expect(tokens.filter { $0.kind == .string }.map { (source as NSString).substring(with: $0.range) } == ["\"세계 # still string\""])
        #expect(tokens.allSatisfy { NSMaxRange($0.range) <= (source as NSString).length })
    }
}
