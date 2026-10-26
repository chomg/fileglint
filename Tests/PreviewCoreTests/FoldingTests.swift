import Foundation
import Testing
@testable import PreviewCore

struct FoldingTests {
    private func document(_ source: String) throws -> PreviewDocument {
        try PreviewDocument(data: Data(source.utf8), format: .json)
    }

    @Test func nestedContainersUseFormattedRangesAndKeepSiblingsDistinct() throws {
        let value = try document(#"{"first":{"items":[1,2]},"next":[3],"empty":{}}"#)
        let pretty = try #require(value.pretty) as NSString
        let regions = value.foldRegions
        #expect(regions.count == 4)
        #expect(regions.map(\.depth) == [0, 1, 2, 1])
        #expect(regions.map(\.kind) == [.object, .object, .array, .array])
        #expect(pretty.substring(with: regions[0].range) == pretty as String)
        #expect(pretty.substring(with: regions[2].range).contains("1,"))
        #expect(!pretty.substring(with: regions[1].range).contains("next"))
        #expect(pretty.substring(with: regions[3].range).contains("3"))
        for region in regions {
            #expect(region.id == region.range.location)
            #expect(region.contentRange.location == region.range.location + 1)
            #expect(NSMaxRange(region.contentRange) == NSMaxRange(region.range) - 1)
            #expect(NSMaxRange(region.range) <= pretty.length)
        }
    }

    @Test func stringsEscapesAndUnicodeCannotCreateFalseContainers() throws {
        let raw = #"{"세계😀":"braces { [ ] } quote: \" slash: \\","array":["\\\"}","[{}]"]}"#
        let value = try document(raw)
        let pretty = try #require(value.pretty) as NSString
        #expect(value.raw == raw)
        #expect(value.foldRegions.count == 2)
        let nested = value.foldRegions[1]
        let arrayOffset = pretty.range(of: "\"array\": [").location + ("\"array\": " as NSString).length
        #expect(nested.range.location == arrayOffset)
        #expect(pretty.substring(with: nested.range).hasPrefix("[\n"))
        #expect(pretty.substring(with: nested.range).hasSuffix("\n  ]"))
    }

    @Test func rootArraysEmptyContainersAndScalarsHaveAppropriateRegions() throws {
        let value = try document("[{}, [], [1], {\"x\": 2}]")
        #expect(value.foldRegions.map(\.kind) == [.array, .array, .object])
        #expect(value.foldRegions.map(\.depth) == [0, 1, 1])
        for source in ["{}", "[]", "42", "true", "null", #""[{}]""#] {
            let scalar = try document(source)
            #expect(scalar.pretty != nil)
            #expect(scalar.foldRegions.isEmpty)
        }
    }

    @Test func parentVisibilityRetainsChildStatesAndSiblings() throws {
        let value = try document(#"{"a":{"child":[1]},"b":[2]}"#)
        let regions = value.foldRegions
        var session = FoldSession(regions: regions)
        #expect(session.collapsedIDs.isEmpty)
        #expect(session.visibleRegions == regions)
        session.toggle(regions[2].id)
        session.toggle(regions[1].id)
        #expect(session.visibleRegions == [regions[0], regions[1], regions[3]])
        #expect(session.collapsedIDs.contains(regions[2].id))
        session.toggle(regions[1].id)
        #expect(session.visibleRegions == regions)
        #expect(session.collapsedIDs == [regions[2].id])
        session.toggle(regions[0].id)
        #expect(session.visibleRegions == [regions[0]])
        session.toggle(regions[0].id)
        #expect(session.collapsedIDs == [regions[2].id])
        session.toggle(-1)
        #expect(session.collapsedIDs == [regions[2].id])
        #expect(FoldSession(regions: regions).collapsedIDs.isEmpty)
        #expect(FoldSession(regions: []).visibleRegions.isEmpty)
    }

    @Test func duplicateKeysBOMAndLiteralSpellingsRemainUntouched() throws {
        let raw = "\u{feff}" + #"{"same":[9007199254740993123],"same":{"n":1.2300e+04,"s":"\u0041"}}"#
        let value = try document(raw)
        let pretty = try #require(value.pretty)
        #expect(value.raw == raw)
        #expect(value.foldRegions.count == 3)
        #expect(pretty.contains("9007199254740993123"))
        #expect(pretty.contains("1.2300e+04"))
        #expect(pretty.contains(#"\u0041"#))
        #expect(!pretty.hasPrefix("\u{feff}"))
        var session = FoldSession(regions: value.foldRegions)
        for region in value.foldRegions { session.toggle(region.id) }
        #expect(value.pretty == pretty)
        #expect(value.raw == raw)
    }

    @Test func invalidAndFormattingLimitedDocumentsHaveNoRegions() throws {
        for source in ["{", "[1,", "{\"x\": [1}", String(repeating: "[", count: 129) + "1" + String(repeating: "]", count: 129),
                       "[1]" + String(repeating: " ", count: 131_072)] {
            let value = try document(source)
            #expect(value.pretty == nil)
            #expect(value.formattingError != nil)
            #expect(value.foldRegions.isEmpty)
        }
    }

    @Test func manySiblingRegionsStayOrderedWithinExistingBounds() throws {
        let raw = "[" + Array(repeating: "[1]", count: 10_000).joined(separator: ",") + "]"
        let value = try document(raw)
        #expect(value.foldRegions.count == 10_001)
        #expect(zip(value.foldRegions, value.foldRegions.dropFirst()).allSatisfy { $0.id < $1.id })
        var session = FoldSession(regions: value.foldRegions)
        session.toggle(value.foldRegions[0].id)
        #expect(session.visibleRegions.count == 1)
    }
}
