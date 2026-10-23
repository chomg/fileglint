import Foundation
import Testing
@testable import PreviewCore

struct StructuredFoldingTests {
    func doc(_ text: String, _ format: DocumentFormat) throws -> PreviewDocument {
        let value = try PreviewDocument(data: Data(text.utf8), format: format)
        try #require(value.pretty != nil, Comment(rawValue: value.formattingError ?? "Missing Prettified"))
        return value
    }
    func assertRanges(_ document: PreviewDocument) {
        let count = (document.pretty! as NSString).length
        let regions = document.foldRegions
        #expect(Set(regions.map(\.id)).count == regions.count)
        for region in regions {
            #expect(region.range.location >= 0 && NSMaxRange(region.range) <= count)
            #expect(region.contentRange.length > 0)
            #expect(region.contentRange.location >= region.range.location)
            #expect(NSMaxRange(region.contentRange) <= NSMaxRange(region.range))
        }
        for (i, a) in regions.enumerated() {
            for b in regions.dropFirst(i + 1) where NSIntersectionRange(a.range, b.range).length > 0 {
                #expect(a.range.location <= b.range.location && NSMaxRange(a.range) >= NSMaxRange(b.range))
            }
        }
    }

    @Test func yamlBlockRangesRespectSiblingCommentsStreamsAndAliases() throws {
        let raw = """
        # heading
        settings: &settings
          # interior comment
          nested:
            items: [1, 2]
          enabled: true
        # sibling comment
        sibling: {value: 3}
        copy: *settings
        # end comment
        ...
        # between documents
        ---
        second:
          values: [4, 5]
        """
        let value = try doc(raw, .yaml)
        assertRanges(value)
        let source = value.pretty! as NSString
        let settings = try #require(value.foldRegions.first { source.substring(with: $0.range).hasPrefix("settings:") && $0.contentRange.location > $0.range.location })
        let content = source.substring(with: settings.contentRange)
        #expect(content.contains("# interior comment"))
        #expect(!content.contains("# sibling comment"))
        #expect(!content.contains("sibling:"))
        #expect(!content.contains("..."))
        #expect(!value.foldRegions.contains { source.substring(with: $0.range).hasPrefix("copy:") })
        var session = FoldSession(regions: value.foldRegions)
        session.toggle(settings.id)
        let projection = FoldProjection(source: value.pretty!, session: session)
        #expect(projection.string.contains("# sibling comment\n"), Comment(rawValue: projection.string))
        #expect(projection.string.contains("sibling:"), Comment(rawValue: projection.string))
        #expect(projection.string.contains("# between documents\n---"))
        #expect(projection.string.contains("second:"))
        #expect(projection.copiedText(in: NSRange(location: 0, length: (projection.string as NSString).length)) == value.pretty)
    }

    @Test func yamlScalarsCannotCreateStructureOrSwallowScalarContent() throws {
        let raw = """
        section:
          literal: |2-
              {not: [a, b]}
            # literal content
          quoted: "brackets { [ ] } and # text"
          multiline: 'words
            # also scalar
            [still scalar]'
        # next section
        next: [{"세계😀": [1,2]}, []]
        """
        let value = try doc(raw, .yaml)
        assertRanges(value)
        let source = value.pretty! as NSString
        for region in value.foldRegions {
            let slice = source.substring(with: region.range)
            #expect(!slice.hasPrefix("{not:"))
            #expect(!slice.hasPrefix("[still scalar]"))
        }
        let section = try #require(value.foldRegions.first { source.substring(with: $0.range).hasPrefix("section:") && $0.contentRange.location > $0.range.location })
        #expect(source.substring(with: section.contentRange).contains("# literal content"))
        #expect(!source.substring(with: section.contentRange).contains("# next section"))
        #expect(value.foldRegions.contains { source.substring(with: $0.range).contains("세계😀") && $0.kind == .mapping })
    }

    @Test func yamlFlowRootSequenceUnicodeAndEmptyScalars() throws {
        for raw in ["[{x: [1, 2]}, {}, []]", "- name: one\n- name: two\n", "{\"세계😀\": [\"#[]{}\", 2]}\n", "a: &a [1,2]\nb: *a\n", "a: &a !<tag:example.com,2026:map> {b: [1,2]}\ncopy: *a\n"] {
            let value = try doc(raw, .yaml)
            assertRanges(value)
            #expect(!value.foldRegions.isEmpty)
        }
        for raw in ["", "# comment only\n", "[]", "{}", "'[] {} # text'", "|\n  {not: [structure]}\n"] {
            #expect(try doc(raw, .yaml).foldRegions.isEmpty)
        }
    }

    @Test func repositoryFixturesRemainUnchangedAndProvideBoundedRegions() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for name in ["folding.json", "folding.yaml", "folding.toml", "comments.yaml", "comments.toml"] {
            let file = root.appendingPathComponent("Fixtures/" + name)
            let before = try Data(contentsOf: file)
            let document = try PreviewDocument.read(file)
            try #require(document.pretty != nil)
            #expect(!document.foldRegions.isEmpty)
            assertRanges(document)
            #expect(try Data(contentsOf: file) == before)
            if ProcessInfo.processInfo.environment["FILEGLINT_CAPTURE_FOLDING"] == "1" {
                let directory = root.appendingPathComponent("artifacts/issue2-visuals")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try document.pretty!.write(to: directory.appendingPathComponent(name + ".pretty"), atomically: true, encoding: .utf8)
            }
        }
    }

    @Test func tomlTablesUseDecodedKeyPathsAndDistinctArrayEntries() throws {
        let raw = """
        # heading
        ["a.b"]
        name="first"
        ["a.b".child]
        numbers=[1,2]
        # other section
        [a.b]
        separate=true
        # first entry
        [[tools]]
        name="one"
        [tools.options]
        enabled=true
        # second entry
        [[tools]]
        name="two"
        # trailing
        """
        let value = try doc(raw, .toml)
        assertRanges(value)
        let source = value.pretty! as NSString
        let parent = try #require(value.foldRegions.first { source.substring(with: $0.range).hasPrefix("[\"a.b\"]") })
        #expect(source.substring(with: parent.range).contains("[\"a.b\".child]"))
        #expect(!source.substring(with: parent.range).contains("# other section"))
        #expect(!source.substring(with: parent.range).contains("[a.b]"))
        let entries = value.foldRegions.filter { $0.kind == .tableEntry }
        #expect(entries.count == 2)
        #expect(source.substring(with: entries[0].range).contains("[tools.options]"))
        #expect(!source.substring(with: entries[0].range).contains("# second entry"))
        #expect(!source.substring(with: entries[1].range).contains("# trailing"))
    }

    @Test func tomlMultilineStringsNestedArraysAndCommentsStayOpaque() throws {
        let raw = #"""
        text="""
        [fake]
        # not a comment
        values=[1,2]
        """
        literal='''
        [[also_fake]]
        {x=1}
        '''
        values=[
          # item comment
          [true]
        ]
        empty=[# no items
        ]
        [real]
        nested={label="[fake] # data",items=[1,2]}
        """#
        let value = try doc(raw, .toml)
        assertRanges(value)
        let source = value.pretty! as NSString
        #expect(value.foldRegions.filter { $0.kind == .table }.count == 1)
        #expect(!value.foldRegions.contains { source.substring(with: $0.range).hasPrefix("[[also_fake]]") })
        #expect(!value.foldRegions.contains { source.substring(with: $0.range).hasPrefix("[fake]") })
        let empty = source.range(of: "[# no items")
        #expect(!value.foldRegions.contains { $0.range.location == empty.location })
        #expect(value.foldRegions.contains { $0.kind == .array && source.substring(with: $0.range).contains("# item comment") })
    }

    @Test func invalidAndOverLimitYAMLTOMLHaveNoStaleFolds() throws {
        for (raw, format) in [("a: [", DocumentFormat.yaml), ("[table", .toml), ("a: 1\n" + String(repeating: "#\n", count: 70_000), .yaml)] {
            let value = try PreviewDocument(data: Data(raw.utf8), format: format)
            #expect(value.pretty == nil)
            #expect(value.foldRegions.isEmpty)
        }
    }

    @Test func aliasesDoNotReexpandAndLargeSourceTablesStayBounded() throws {
        let yaml = "- &a [" + Array(repeating: "1", count: 2_000).joined(separator: ",") + "]\n" + String(repeating: "- *a\n", count: 2_000)
        let aliases = try doc(yaml, .yaml)
        #expect(aliases.foldRegions.count == 2)
        let toml = (0..<5_000).map { "[table\($0)]\nvalue = 1\n" }.joined()
        #expect(toml.utf8.count <= 131_072)
        let tables = try doc(toml, .toml)
        #expect(tables.foldRegions.count == 5_000)
        #expect(tables.foldRegions.allSatisfy { $0.kind == .table })
    }

    @Test func blockAnchorFoldsDoNotAbsorbAliasSiblingsAndComplexKeysKeepDistinctRanges() throws {
        let block = try doc("- &a\n  name: one\n  nested:\n    items: [1, 2]\n# alias comment\n- *a\n-\n  name: two\n  extra: true\n", .yaml)
        assertRanges(block)
        let source = block.pretty! as NSString
        let anchor = try #require(block.foldRegions.first { $0.kind == .mapping && source.substring(with: $0.range).hasPrefix("&a") })
        #expect(!source.substring(with: anchor.range).contains("*a"))
        #expect(!source.substring(with: anchor.range).contains("# alias comment"))
        let second = try #require(block.foldRegions.first { $0.kind == .mapping && source.substring(with: $0.range).contains("name: two") })
        #expect(source.substring(with: second.range).contains("extra: true"))
        let complex = try doc("{key: '[not structure]'}: 1\nsibling: [2]\n", .yaml)
        assertRanges(complex)
        #expect(complex.foldRegions.filter { $0.kind == .mapping }.count == 2)
        let spans = complex.foldRegions.map { (complex.pretty! as NSString).substring(with: $0.range) }
        #expect(spans.contains("{key: '[not structure]'}"))
        #expect(spans[0].contains("sibling:"))
        var state = FoldSession(regions: complex.foldRegions)
        let complexKey = try #require(complex.foldRegions.first { (complex.pretty! as NSString).substring(with: $0.range) == "{key: '[not structure]'}" })
        state.toggle(complexKey.id)
        let shown = FoldProjection(source: complex.pretty!, session: state)
        #expect(shown.copiedText(in: NSRange(location: 0, length: (shown.string as NSString).length)) == complex.pretty)
        let aliasedKey = try doc("name: &key old\nmap:\n  *key:\n    sub: [1, 2]\nsibling: 3\n", .yaml)
        assertRanges(aliasedKey)
        #expect(aliasedKey.foldRegions.contains { (aliasedKey.pretty! as NSString).substring(with: $0.range).hasPrefix("*key:") })
    }

    @Test func projectionCopiesLogicalSelectionsAndNeverCopiesControlsOrMarkers() throws {
        let value = try doc("{\"first\":[1,2],\"last\":[3,4],\"literal\":\" … \u{fffc}\"}", .json)
        let source = value.pretty!
        var session = FoldSession(regions: value.foldRegions)
        let child = value.foldRegions[1]
        session.toggle(child.id)
        let display = FoldProjection(source: source, session: session)
        let all = NSRange(location: 0, length: (display.string as NSString).length)
        #expect(display.copiedText(in: all) == source)
        let hidden = try #require(display.segments.first { $0.kind == .placeholder(child.id) })
        #expect(display.copiedText(in: hidden.displayRange) == (source as NSString).substring(with: child.contentRange))
        #expect(display.copiedText(in: NSRange(location: hidden.displayRange.location + 1, length: 1)) == (source as NSString).substring(with: child.contentRange))
        let first = (source as NSString).range(of: "\"first\"").location
        let last = (source as NSString).range(of: "\"last\"").location
        let start = display.displayOffset(forSourceOffset: first)
        let end = display.displayOffset(forSourceOffset: last)
        #expect(display.copiedText(in: NSRange(start..<end)) == (source as NSString).substring(with: NSRange(first..<last)))
        for control in display.controls { #expect(display.copiedText(in: control.displayRange).isEmpty) }
        #expect(display.copiedText(in: NSRange(location: NSNotFound, length: 1)).isEmpty)
        session.toggle(child.id)
        let expanded = FoldProjection(source: source, session: session)
        #expect(expanded.copiedText(in: NSRange(location: 0, length: (expanded.string as NSString).length)) == source)
    }
}
