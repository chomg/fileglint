import Foundation

/// Coordinates address the complete, immutable Prettified string in UTF-16.
/// A region's ID is local to that string and must not survive a document change.
public struct FoldRegion: Equatable, Sendable, Identifiable {
    public enum Kind: String, Equatable, Sendable { case object, array, mapping, sequence, table, tableEntry }
    public var id: Int { identity ?? range.location }
    public let kind: Kind
    public let range: NSRange
    public let contentRange: NSRange
    public let depth: Int
    public let controlOffset: Int
    private let identity: Int?

    init(kind: Kind, range: NSRange, contentRange: NSRange, depth: Int, id: Int? = nil, controlOffset: Int? = nil) {
        self.kind = kind; self.range = range; self.contentRange = contentRange
        self.depth = depth; self.identity = id
        self.controlOffset = controlOffset ?? range.location
    }
}

/// Session state is independent of AppKit and never alters the formatted text.
/// Create a fresh session on every mode switch or document change.
public struct FoldSession: Sendable {
    public let regions: [FoldRegion]
    public private(set) var collapsedIDs: Set<Int> = []
    private let validIDs: Set<Int>

    public init(regions: [FoldRegion]) {
        self.regions = regions.sorted {
            if $0.range.location != $1.range.location { return $0.range.location < $1.range.location }
            if $0.range.length != $1.range.length { return $0.range.length > $1.range.length }
            return $0.depth < $1.depth
        }
        validIDs = Set(regions.map(\.id))
    }

    public mutating func toggle(_ id: Int) {
        guard validIDs.contains(id) else { return }
        if !collapsedIDs.insert(id).inserted { collapsedIDs.remove(id) }
    }

    /// Hiding an ancestor suppresses its descendants without resetting them.
    /// Some block headings contain structured keys. Keep controls in a retained
    /// heading visible; only anchors inside hidden interiors are suppressed.
    public var visibleRegions: [FoldRegion] {
        var result = [FoldRegion]()
        var hidden = [NSRange]()
        let ordered = regions.sorted { $0.controlOffset == $1.controlOffset ? $0.depth < $1.depth : $0.controlOffset < $1.controlOffset }
        for region in ordered {
            hidden.removeAll { NSMaxRange($0) <= region.controlOffset }
            guard !hidden.contains(where: { NSLocationInRange(region.controlOffset, $0) }) else { continue }
            result.append(region)
            if collapsedIDs.contains(region.id) { hidden.append(region.contentRange) }
        }
        return result
    }
}

enum Folding {
    /// Input has already passed JSON parsing and the formatting/output limits.
    /// Match structural tokens without interpreting delimiters inside strings.
    static func json(_ formatted: String) -> [FoldRegion] {
        struct Start {
            let offset: Int
            let kind: FoldRegion.Kind
            let depth: Int
        }
        let units = Array(formatted.utf16)
        var stack = [Start]()
        var regions = [FoldRegion]()
        var quoted = false
        var escaped = false
        for (offset, unit) in units.enumerated() {
            if quoted {
                if escaped { escaped = false }
                else if unit == 92 { escaped = true }
                else if unit == 34 { quoted = false }
                continue
            }
            switch unit {
            case 34: quoted = true
            case 123, 91:
                stack.append(Start(offset: offset, kind: unit == 123 ? .object : .array, depth: stack.count))
            case 125, 93:
                guard let start = stack.popLast(),
                      (start.kind == .object && unit == 125) || (start.kind == .array && unit == 93) else { return [] }
                let content = (start.offset + 1)..<offset
                // Formatting renders empty containers as {} or []. Looking at
                // whitespace too keeps this helper safe for validated input
                // produced by another whitespace-only formatter.
                guard units[content].contains(where: { ![9, 10, 13, 32].contains($0) }) else { continue }
                regions.append(FoldRegion(kind: start.kind, range: NSRange(start.offset..<(offset + 1)),
                                          contentRange: NSRange(content), depth: start.depth, controlOffset: start.offset + 1))
            default: break
            }
        }
        guard stack.isEmpty, !quoted else { return [] }
        return regions.sorted { $0.range.location < $1.range.location }
    }
}
