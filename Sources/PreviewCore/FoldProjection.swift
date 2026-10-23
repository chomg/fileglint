import Foundation

/// Presentation-only characters have explicit source mappings. Copy never
/// relies on searching for or removing a marker that might occur in the file.
public struct FoldProjection: Sendable {
    public struct Segment: Sendable {
        public enum Kind: Equatable, Sendable { case source, control(Int), placeholder(Int), annotation }
        public let kind: Kind
        public let sourceRange: NSRange
        public let displayRange: NSRange
    }
    public let source: String
    public let string: String
    public let segments: [Segment]
    public let controls: [Segment]

    public init(source: String, session: FoldSession) {
        self.source = source
        let original = source as NSString
        enum Event { case control(FoldRegion), hide(FoldRegion) }
        var events = [(Int, Int, Event)]()
        for (index, region) in session.visibleRegions.enumerated() {
            events.append((region.controlOffset, index * 2, .control(region)))
            if session.collapsedIDs.contains(region.id) { events.append((region.contentRange.location, index * 2 + 1, .hide(region))) }
        }
        events.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        var output = "", result = [Segment](), cursor = 0, displayed = 0
        func append(_ text: String, source: NSRange, kind: Segment.Kind) {
            let length = (text as NSString).length
            guard length > 0 else { return }
            result.append(Segment(kind: kind, sourceRange: source, displayRange: NSRange(location: displayed, length: length)))
            output += text; displayed += length
        }
        for (offset, _, event) in events {
            guard offset >= cursor, offset <= original.length else { continue }
            if offset > cursor { let range = NSRange(cursor..<offset); append(original.substring(with: range), source: range, kind: .source); cursor = offset }
            switch event {
            case .control(let region):
                let point = NSRange(location: offset, length: 0)
                if region.range == region.contentRange { append("\(region.kind.rawValue.capitalized) ", source: point, kind: .annotation) }
                append("\u{fffc}", source: point, kind: .control(region.id))
                if region.range == region.contentRange && !session.collapsedIDs.contains(region.id) {
                    let column = region.range.location - original.lineRange(for: NSRange(location: region.range.location, length: 0)).location
                    let padding = String(repeating: " ", count: min(128, column))
                    append("\n\(padding)", source: point, kind: .annotation)
                }
            case .hide(let region):
                let range = region.contentRange
                guard range.location == cursor, NSMaxRange(range) <= original.length else { continue }
                append(" … ", source: range, kind: .placeholder(region.id)); cursor = NSMaxRange(range)
            }
        }
        if cursor < original.length { let range = NSRange(cursor..<original.length); append(original.substring(with: range), source: range, kind: .source) }
        string = output; segments = result
        controls = result.filter { if case .control = $0.kind { return true }; return false }
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
            case .control, .annotation: break
            case .placeholder: result += original.substring(with: segment.sourceRange)
            case .source:
                result += original.substring(with: NSRange(location: segment.sourceRange.location + overlap.location - segment.displayRange.location, length: overlap.length))
            }
        }
        return result
    }

    public func displayOffset(forSourceOffset offset: Int, trailing: Bool = false) -> Int {
        for segment in segments where segment.sourceRange.length > 0 && offset <= NSMaxRange(segment.sourceRange) {
            guard offset >= segment.sourceRange.location else { return segment.displayRange.location }
            if case .placeholder = segment.kind {
                return offset == segment.sourceRange.location || (!trailing && offset < NSMaxRange(segment.sourceRange))
                    ? segment.displayRange.location : NSMaxRange(segment.displayRange)
            }
            return segment.displayRange.location + offset - segment.sourceRange.location
        }
        return (string as NSString).length
    }

    public func sourceOffset(forDisplayOffset offset: Int, trailing: Bool = false) -> Int {
        for segment in segments where offset < NSMaxRange(segment.displayRange) {
            let delta = max(0, offset - segment.displayRange.location)
            switch segment.kind {
            case .control, .annotation: return segment.sourceRange.location
            case .source: return segment.sourceRange.location + delta
            case .placeholder: return trailing ? NSMaxRange(segment.sourceRange) : segment.sourceRange.location
            }
        }
        return (source as NSString).length
    }
}
