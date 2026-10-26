import Foundation
import Yams
import TOMLKit

/// Line coordinates stay in UTF-16; libyaml columns count Unicode scalars.
private struct FoldSource {
    struct Line {
        let start: Int
        let end: Int
        let contentEnd: Int
        let indent: Int
        let text: String
        let columns: [Int]
    }
    let units: [UInt16]
    let lines: [Line]

    init(_ source: String) {
        units = Array(source.utf16)
        var result = [Line](), start = 0
        while start < units.count {
            var end = start
            while end < units.count && ![10, 13, 0x85, 0x2028, 0x2029].contains(units[end]) { end += 1 }
            let contentEnd = end
            if end < units.count {
                let cr = units[end] == 13
                end += 1
                if cr && end < units.count && units[end] == 10 { end += 1 }
            }
            var columns = [Int](), i = start
            while i < contentEnd {
                columns.append(i)
                i += (0xD800...0xDBFF).contains(units[i]) ? 2 : 1
            }
            columns.append(contentEnd)
            let text = String(decoding: units[start..<contentEnd], as: UTF16.self)
            result.append(Line(start: start, end: end, contentEnd: contentEnd,
                               indent: text.prefix { $0 == " " || $0 == "\t" }.count, text: text, columns: columns))
            start = end
        }
        lines = result
    }
    func line(at offset: Int) -> Int {
        var low = 0, high = lines.count
        while low < high {
            let mid = (low + high) / 2
            if lines[mid].start <= offset { low = mid + 1 } else { high = mid }
        }
        return max(0, low - 1)
    }
    func offset(_ mark: Mark?) -> Int? {
        guard let mark, mark.line > 0, mark.line <= lines.count,
              mark.column > 0, mark.column <= lines[mark.line - 1].columns.count else { return nil }
        return lines[mark.line - 1].columns[mark.column - 1]
    }
    func isProtected(_ offset: Int, _ spans: [NSRange]) -> Bool {
        // Spans are sorted, disjoint scalar tokens.
        var low = 0, high = spans.count
        while low < high {
            let mid = (low + high) / 2
            if spans[mid].location <= offset { low = mid + 1 } else { high = mid }
        }
        return low > 0 && offset < NSMaxRange(spans[low - 1])
    }
    func sectionEnd(before bound: Int, indent: Int, protected: [NSRange]) -> Int {
        guard !lines.isEmpty, bound > 0 else { return 0 }
        var index = line(at: bound - 1)
        while index >= 0 {
            let row = lines[index], trimmed = row.text.trimmingCharacters(in: .whitespaces)
            let boundaryComment = trimmed.hasPrefix("#") && row.indent <= indent
                && !isProtected(row.start + row.indent, protected)
            if (!trimmed.isEmpty && !boundaryComment) || isProtected(row.start, protected) { return min(bound, row.contentEnd) }
            index -= 1
        }
        return 0
    }
    func quoteEnd(_ start: Int, quote: UInt16) -> Int {
        var i = start + 1
        while i < units.count {
            if quote == 34 && units[i] == 92 { i = min(i + 2, units.count) }
            else if units[i] == quote {
                if quote == 39 && i + 1 < units.count && units[i + 1] == quote { i += 2 }
                else { return i + 1 }
            } else { i += 1 }
        }
        return units.count
    }
    func flowEnd(_ start: Int, before bound: Int, protected: [NSRange]) -> Int? {
        var stack = [UInt16](), i = start
        while i < min(bound, units.count) {
            if isProtected(i, protected) {
                // Binary search above locates the containing token; skip its end.
                var low = 0, high = protected.count
                while low < high { let mid = (low + high) / 2; if protected[mid].location <= i { low = mid + 1 } else { high = mid } }
                i = NSMaxRange(protected[low - 1]); continue
            }
            let u = units[i]
            if u == 91 || u == 123 { stack.append(u) }
            if u == 93 || u == 125 {
                guard let open = stack.popLast(), (open == 91 && u == 93) || (open == 123 && u == 125) else { return nil }
                if stack.isEmpty { return i + 1 }
            }
            i += 1
        }
        return nil
    }
    func flowStart(at offset: Int, expected: UInt16, before bound: Int) -> Int? {
        var i = offset
        while i < min(bound, units.count) {
            if [9, 10, 13, 32].contains(units[i]) { i += 1; continue }
            if units[i] == 35 { i = lines[line(at: i)].end; continue }
            if units[i] == 38 || units[i] == 33 {
                if units[i] == 33 && i + 1 < units.count && units[i + 1] == 60 {
                    i += 2
                    while i < units.count && units[i] != 62 { i += 1 }
                    i = min(i + 1, units.count)
                } else {
                    i += 1
                    while i < units.count && ![9, 10, 13, 32].contains(units[i]) { i += 1 }
                }
                continue
            }
            return units[i] == expected ? i : nil
        }
        return nil
    }
    func sequenceHeader(at offset: Int) -> Int {
        let index = line(at: offset)
        var previous = index - 1
        while previous >= 0 {
            let text = lines[previous].text.trimmingCharacters(in: .whitespaces)
            if text.isEmpty || text.hasPrefix("#") { previous -= 1; continue }
            if lines[previous].indent < lines[index].indent && (text == "-" || text.hasPrefix("- #")) { return lines[previous].start + lines[previous].indent }
            break
        }
        return offset
    }
    func blockBound(after header: Int, before upper: Int, protected: [NSRange]) -> Int {
        let index = line(at: header), indent = lines[index].indent
        for row in lines.dropFirst(index + 1) {
            if row.start >= upper { break }
            let trimmed = row.text.trimmingCharacters(in: .whitespaces)
            if row.indent <= indent && !trimmed.isEmpty && !trimmed.hasPrefix("#") && !isProtected(row.start + row.indent, protected) { return row.start }
        }
        return upper
    }
    func mappingHeader(key: Int, value: Int) -> Int {
        let valueLine = line(at: value), keyLine = line(at: key)
        guard valueLine > keyLine else { return key }
        let row = lines[valueLine]
        let prefix = String(decoding: units[row.start..<value], as: UTF16.self)
        if row.text.trimmingCharacters(in: .whitespaces).hasPrefix("*") && prefix.contains(":") { return row.start + row.indent }
        var previous = valueLine - 1
        while previous >= keyLine {
            let text = lines[previous].text.trimmingCharacters(in: .whitespaces)
            if text.isEmpty || text.hasPrefix("#") { previous -= 1; continue }
            if lines[previous].indent < row.indent || (lines[previous].indent == row.indent && text.hasSuffix(":")) { return lines[previous].start + lines[previous].indent }
            break
        }
        return key
    }
}

extension Folding {
    static func yaml(_ text: String) throws -> [FoldRegion] {
        let source = FoldSource(text)
        guard !source.lines.isEmpty else { return [] }
        let parser = try Yams.Parser(yaml: text)
        var roots = [Node]()
        while let root = try parser.nextRoot() { roots.append(root) }
        func complexFirstKey(_ map: Node.Mapping, offset: Int) -> Bool {
            guard let first = map.first?.key, source.offset(first.mark) == offset else { return false }
            switch first { case .mapping, .sequence: return true; default: return false }
        }
        var protected = [NSRange](), scalarSeen = Set<Int>(), containers = Set<String>()
        func collect(_ node: Node) {
            guard let offset = source.offset(node.mark) else { return }
            switch node {
            case .mapping(let map):
                guard containers.insert("\(offset)-map-\(complexFirstKey(map, offset: offset))").inserted else { return }
                for (key, value) in map { collect(key); collect(value) }
            case .sequence(let seq):
                guard containers.insert("\(offset)-sequence").inserted else { return }
                for child in seq { collect(child) }
            case .scalar(let scalar):
                guard scalarSeen.insert(offset).inserted else { return }
                let row = source.lines[source.line(at: offset)]
                if scalar.style == .singleQuoted || scalar.style == .doubleQuoted {
                    let quote: UInt16 = scalar.style == .singleQuoted ? 39 : 34
                    if let start = (offset..<row.contentEnd).first(where: { source.units[$0] == quote }) {
                        protected.append(NSRange(start..<source.quoteEnd(start, quote: quote)))
                    }
                } else if scalar.style == .literal || scalar.style == .folded {
                    let header = source.line(at: offset)
                    var end = row.end, contentIndent: Int?
                    let headerText = String(decoding: source.units[offset..<row.contentEnd], as: UTF16.self).split(separator: "#", maxSplits: 1).first ?? ""
                    let indicator: Character = scalar.style == .literal ? "|" : ">"
                    if let marker = headerText.lastIndex(of: indicator), let digit = headerText[headerText.index(after: marker)...].first(where: { $0 >= "1" && $0 <= "9" }), let amount = digit.wholeNumberValue { contentIndent = row.indent + amount }
                    for next in source.lines.dropFirst(header + 1) {
                        if !next.text.trimmingCharacters(in: .whitespaces).isEmpty {
                            if contentIndent == nil { contentIndent = next.indent }
                            guard next.indent >= (contentIndent ?? 0), next.indent > row.indent else { break }
                        }
                        end = next.end
                    }
                    protected.append(NSRange(offset..<end))
                }
            case .alias: break
            }
        }
        for root in roots { collect(root) }
        // Comments outside scalar tokens, including URLs containing '#', are
        // recognized only after a separation space (YAML's comment rule).
        protected.sort { $0.location < $1.location }
        let scalarRanges = protected
        var comments = [NSRange]()
        for row in source.lines {
            var i = row.start
            while i < row.contentEnd {
                if source.units[i] == 35 && (i == row.start || [9, 32].contains(source.units[i - 1]))
                    && !source.isProtected(i, scalarRanges) {
                    comments.append(NSRange(i..<row.contentEnd)); break
                }
                i += 1
            }
        }
        protected = (scalarRanges + comments).sorted { $0.location < $1.location }
        let separators = source.lines.filter { row in
            guard row.indent == 0, !source.isProtected(row.start, protected) else { return false }
            let s = row.text
            return ["---", "..."].contains { marker in
                s == marker || s.hasPrefix(marker + " ") || s.hasPrefix(marker + "\t")
            }
        }.map(\.start)
        var result = [FoldRegion](), visited = Set<String>()
        func visit(_ node: Node, header: Int?, upper: Int, depth: Int) {
            guard let offset = source.offset(node.mark), offset < upper else { return }
            let kind: FoldRegion.Kind, complexKey: Bool, count: Int
            switch node {
            case .mapping(let map): kind = .mapping; complexKey = complexFirstKey(map, offset: offset); count = map.count
            case .sequence(let seq): kind = .sequence; complexKey = false; count = seq.count
            default: return
            }
            guard count > 0 else { return }
            // Container styles on composed nodes need not retain the original
            // spelling. Inspect syntax at the parser's mark, after attributes.
            let open = complexKey ? nil : source.flowStart(at: offset, expected: kind == .mapping ? 123 : 91, before: upper)
            let flow = open != nil
            guard visited.insert("\(offset)-\(kind.rawValue)-\(flow)").inserted else { return }
            let identity = offset * 2 + (flow ? 1 : 0)
            let end: Int
            if let open {
                guard let close = source.flowEnd(open, before: upper, protected: protected) else { return }
                end = close
                result.append(FoldRegion(kind: kind, range: NSRange(open..<end), contentRange: NSRange((open + 1)..<(end - 1)), depth: depth, id: identity, controlOffset: open + 1))
            } else {
                let start = header ?? offset
                let row = source.lines[source.line(at: start)]
                let bound = header.map { source.blockBound(after: $0, before: upper, protected: scalarRanges) } ?? upper
                end = source.sectionEnd(before: bound, indent: row.indent, protected: scalarRanges)
                // Implicit stream roots have no visible heading and no
                // document-wide control. Still visit their actual children.
                // Other block containers keep their first physical source line.
                let contentStart = row.contentEnd
                if depth > 0 && end > contentStart {
                    result.append(FoldRegion(kind: kind, range: NSRange(start..<end), contentRange: NSRange(contentStart..<end), depth: depth, id: identity, controlOffset: contentStart))
                }
            }
            if case .mapping(let map) = node {
                let pairs = Array(map).filter { max(source.offset($0.key.mark) ?? -1, source.offset($0.value.mark) ?? -1) >= offset }
                for (index, pair) in pairs.enumerated() {
                    guard let key = source.offset(pair.key.mark), let value = source.offset(pair.value.mark), value >= key else { continue }
                    let heading = source.mappingHeader(key: key, value: value)
                    let next: Int? = index + 1 < pairs.count ? {
                        guard let k = source.offset(pairs[index + 1].key.mark), let v = source.offset(pairs[index + 1].value.mark) else { return nil }
                        return source.mappingHeader(key: k, value: v)
                    }() : nil
                    let bound = min(end, next.map { source.lines[source.line(at: $0)].start } ?? end)
                    visit(pair.key, header: nil, upper: value, depth: depth + 1)
                    visit(pair.value, header: flow ? nil : heading, upper: flow ? end : bound, depth: depth + 1)
                }
            } else if case .sequence(let sequence) = node {
                let items = sequence.filter { (source.offset($0.mark) ?? -1) >= offset }
                for item in items {
                    guard let position = source.offset(item.mark) else { continue }
                    // Yams resolves aliases to the anchor node/mark. Bound block
                    // entries by physical indentation, not a resolved alias's
                    // earlier mark, so an anchor never absorbs sibling aliases.
                    visit(item, header: flow ? nil : source.sequenceHeader(at: position), upper: end, depth: depth + 1)
                }
            }
        }
        for root in roots {
            guard let start = source.offset(root.mark) else { continue }
            let upper = separators.first { $0 > start } ?? source.units.count
            visit(root, header: nil, upper: upper, depth: 0)
        }
        return FoldSession(regions: result).regions
    }

    static func toml(_ text: String) -> [FoldRegion] {
        let source = FoldSource(text)
        let tokens = SourceFormatting.tomlTokens(text)
        let protected = tokens.map(\.range)
        let strings = tokens.filter { $0.kind == .string }.map(\.range)
        let comments = tokens.filter { $0.kind == .comment }.map(\.range)
        var commentStarts = [Int: Int]()
        for comment in comments { commentStarts[source.lines[source.line(at: comment.location)].start] = comment.location }
        // TOML keys use exact decoded code points. Swift String equality would
        // conflate distinct NFC/NFD names and fold unrelated table sections.
        struct Header { let offset: Int; let end: Int; let path: [Data]; let array: Bool }
        var headers = [Header](), headerSpans = [NSRange]()
        var valueDepth = 0
        for row in source.lines {
            let start = row.start + row.indent
            var isHeader = false
            defer {
                if !isHeader {
                    for i in row.start..<row.contentEnd where !source.isProtected(i, protected) {
                        if source.units[i] == 91 || source.units[i] == 123 { valueDepth += 1 }
                        if source.units[i] == 93 || source.units[i] == 125 { valueDepth -= 1 }
                    }
                }
            }
            guard valueDepth == 0, start < row.contentEnd, source.units[start] == 91, !source.isProtected(start, protected) else { continue }
            // Only top-level bracket lines outside a multiline value are
            // headers. TOMLKit validates the isolated header before inclusion.
            let line = row.text.trimmingCharacters(in: .whitespaces)
            var end = row.contentEnd
            if let comment = commentStarts[row.start] { end = comment }
            let declaration = String(decoding: source.units[start..<end], as: UTF16.self).trimmingCharacters(in: .whitespaces)
            let array = line.hasPrefix("[[")
            guard declaration.hasSuffix(array ? "]]" : "]") else { continue }
            let inner = String(declaration.dropFirst(array ? 2 : 1).dropLast(array ? 2 : 1))
            guard let table = try? TOMLTable(string: "[\(inner)]\n_fileglint_probe = 0") else { continue }
            var path = [String](), current = table
            while current.keys.count == 1, let key = current.keys.first, let child = current[key]?.table { path.append(key); current = child }
            guard !path.isEmpty else { continue }
            headers.append(Header(offset: start, end: row.contentEnd, path: path.map { Data($0.utf8) }, array: array))
            headerSpans.append(NSRange(start..<row.contentEnd))
            isHeader = true
        }
        // Bracket-looking multiline array rows cannot parse as standalone TOML
        // headers except quoted strings; those are protected tokens above.
        var ends = Array(repeating: source.units.count, count: headers.count), stack = [Int]()
        for (i, header) in headers.enumerated() {
            while let previous = stack.last {
                let path = headers[previous].path
                if header.path.count > path.count && Array(header.path.prefix(path.count)) == path { break }
                ends[previous] = source.lines[source.line(at: header.offset)].start
                stack.removeLast()
            }
            stack.append(i)
        }
        var result = [FoldRegion]()
        for (index, header) in headers.enumerated() {
            let end = source.sectionEnd(before: ends[index], indent: 0, protected: strings)
            guard end > header.end else { continue }
            let body = String(decoding: source.units[header.end..<end], as: UTF16.self)
            // A comment-only table is empty; leave its comments visible.
            guard body.split(whereSeparator: \.isNewline).contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }) else { continue }
            result.append(FoldRegion(kind: header.array ? .tableEntry : .table, range: NSRange(header.offset..<end), contentRange: NSRange(header.end..<end), depth: header.path.count - 1, controlOffset: header.end))
        }
        // Match arrays/inline tables only outside all opaque tokens and headers.
        let ignored = (protected + headerSpans).sorted { $0.location < $1.location }
        var opens = [(Int, UInt16)](), token = 0
        var i = 0
        while i < source.units.count {
            while token < ignored.count && NSMaxRange(ignored[token]) <= i { token += 1 }
            if token < ignored.count && ignored[token].location <= i { i = NSMaxRange(ignored[token]); continue }
            let u = source.units[i]
            if u == 91 || u == 123 { opens.append((i, u)) }
            if u == 93 || u == 125, let (start, _) = opens.popLast() {
                let content = NSRange((start + 1)..<i)
                let significant = ((start + 1)..<i).contains { ![9, 10, 13, 32].contains(source.units[$0]) && !source.isProtected($0, comments) }
                if significant { result.append(FoldRegion(kind: u == 93 ? .array : .object, range: NSRange(start..<(i + 1)), contentRange: content, depth: opens.count + 1, controlOffset: start + 1)) }
            }
            i += 1
        }
        return FoldSession(regions: result).regions
    }
}
