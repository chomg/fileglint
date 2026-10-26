import Foundation

/// Only source text and collapsed placeholders participate in selection.
/// Gutter controls have positions, but never insert characters into the text.
public struct FoldProjection: Sendable {
    public struct Segment: Sendable {
        public enum Kind: Equatable, Sendable { case source, placeholder(Int) }
        public let kind: Kind
        public let sourceRange: NSRange
        public let displayRange: NSRange
    }
    public struct Control: Sendable {
        public let id: Int
        public let displayOffset: Int
    }
    public let source: String
    public let string: String
    public let segments: [Segment]
    public let controls: [Control]

    public init(source: String, session: FoldSession) {
        self.source = source
        let original = source as NSString
        let visible = session.visibleRegions
        let hidden = visible.filter { session.collapsedIDs.contains($0.id) }.sorted {
            $0.contentRange.location < $1.contentRange.location
        }
        var output = "", result = [Segment](), cursor = 0, displayed = 0
        func append(_ text: String, source: NSRange, kind: Segment.Kind) {
            let length = (text as NSString).length
            guard length > 0 else { return }
            result.append(Segment(kind: kind, sourceRange: source, displayRange: NSRange(location: displayed, length: length)))
            output += text; displayed += length
        }
        for region in hidden {
            let range = region.contentRange
            guard range.location >= cursor, NSMaxRange(range) <= original.length else { continue }
            if range.location > cursor {
                let retained = NSRange(cursor..<range.location)
                append(original.substring(with: retained), source: retained, kind: .source)
            }
            append(" … ", source: range, kind: .placeholder(region.id))
            cursor = NSMaxRange(range)
        }
        if cursor < original.length {
            let range = NSRange(cursor..<original.length)
            append(original.substring(with: range), source: range, kind: .source)
        }
        string = output; segments = result

        // Build line indexes once rather than repeatedly scanning a long flow
        // line for every nested container. Choose the outermost starting region
        // on each source line, then avoid collisions after multiline folds.
        func starts(_ text: String) -> [Int] {
            let units = Array(text.utf16)
            var rows = [0]
            for (i, unit) in units.enumerated() {
                if unit == 10 || unit == 0x85 || unit == 0x2028 || unit == 0x2029 || (unit == 13 && (i + 1 == units.count || units[i + 1] != 10)) { rows.append(i + 1) }
            }
            return rows
        }
        func lineStart(_ offset: Int, _ rows: [Int]) -> Int {
            var low = 0, high = rows.count
            while low < high { let mid = (low + high) / 2; if rows[mid] <= offset { low = mid + 1 } else { high = mid } }
            return rows[max(0, low - 1)]
        }
        let sourceRows = starts(source), displayRows = starts(output)
        var sourceLines = Set<Int>(), displayLines = Set<Int>(), buttons = [Control]()
        let ordered = visible.sorted {
            $0.range.location == $1.range.location ? $0.range.length > $1.range.length : $0.range.location < $1.range.location
        }
        for region in ordered {
            let row = lineStart(region.range.location, sourceRows)
            guard sourceLines.insert(row).inserted else { continue }
            let position = Self.displayOffset(row, segments: result, count: displayed, trailing: false)
            let displayRow = lineStart(position, displayRows)
            guard displayLines.insert(displayRow).inserted else { continue }
            buttons.append(Control(id: region.id, displayOffset: displayRow))
        }
        controls = buttons
    }

    public func copiedText(in selection: NSRange) -> String {
        let count = (string as NSString).length
        guard selection.location != NSNotFound, selection.location >= 0, selection.location <= count,
              selection.length >= 0, selection.length <= count - selection.location else { return "" }
        let original = source as NSString
        var result = ""
        for segment in segments {
            let overlap = NSIntersectionRange(selection, segment.displayRange)
            guard overlap.length > 0 else { continue }
            switch segment.kind {
            case .placeholder: result += original.substring(with: segment.sourceRange)
            case .source:
                result += original.substring(with: NSRange(location: segment.sourceRange.location + overlap.location - segment.displayRange.location, length: overlap.length))
            }
        }
        return result
    }

    private static func displayOffset(_ offset: Int, segments: [Segment], count: Int, trailing: Bool) -> Int {
        var low = 0, high = segments.count
        while low < high { let mid = (low + high) / 2; if NSMaxRange(segments[mid].sourceRange) < offset { low = mid + 1 } else { high = mid } }
        guard low < segments.count else { return count }
        let segment = segments[low]
        guard offset >= segment.sourceRange.location else { return segment.displayRange.location }
        if case .placeholder = segment.kind {
            return offset == segment.sourceRange.location || (!trailing && offset < NSMaxRange(segment.sourceRange))
                ? segment.displayRange.location : NSMaxRange(segment.displayRange)
        }
        return segment.displayRange.location + offset - segment.sourceRange.location
    }

    public func displayOffset(forSourceOffset offset: Int, trailing: Bool = false) -> Int {
        Self.displayOffset(offset, segments: segments, count: (string as NSString).length, trailing: trailing)
    }

    public func sourceOffset(forDisplayOffset offset: Int, trailing: Bool = false) -> Int {
        for segment in segments where offset < NSMaxRange(segment.displayRange) {
            let delta = max(0, offset - segment.displayRange.location)
            switch segment.kind {
            case .source: return segment.sourceRange.location + delta
            case .placeholder: return trailing ? NSMaxRange(segment.sourceRange) : segment.sourceRange.location
            }
        }
        return (source as NSString).length
    }
}
