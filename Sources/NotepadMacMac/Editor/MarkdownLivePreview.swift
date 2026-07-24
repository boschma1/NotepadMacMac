import AppKit

/// Obsidian-style live Markdown preview.
///
/// Operates directly on the editor's `NSTextStorage`, restyling Markdown so
/// the formatting is *rendered* rather than shown as raw syntax: headings get
/// larger/bold type, `**bold**` shows bold, `*italic*` shows italic, `` `code` ``
/// gets a mono color, and `[text](url)` shows just the link text. The syntax
/// markers (`#`, `**`, `*`, `` ` ``, `[`/`]`, `(url)`) are collapsed to a near-zero
/// transparent glyph so they effectively disappear.
///
/// To keep the document fully editable, markers on the line that currently
/// holds the caret are left at full size — so moving the caret onto a line
/// reveals its raw Markdown for editing, exactly like Obsidian's live preview.
enum MarkdownLivePreview {

    /// Restyle the Markdown in `range` of `storage`. `baseFont` is the editor's
    /// default font; `activeLineRange` (if any) is the caret's line, whose
    /// markers stay visible. Assumes the caller has already applied default
    /// font/color and is inside a begin/endEditing block.
    static func apply(to storage: NSTextStorage,
                      range: NSRange,
                      baseFont: NSFont,
                      theme: SyntaxTheme,
                      activeLineRange: NSRange?) {
        let text = storage.string as NSString
        let fm = NSFontManager.shared

        let bold = fm.convert(baseFont, toHaveTrait: .boldFontMask)
        let italic = fm.convert(baseFont, toHaveTrait: .italicFontMask)

        func hide(_ r: NSRange) {
            if let active = activeLineRange, NSIntersectionRange(r, active).length > 0 { return }
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 0.01), range: r)
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: r)
        }

        func style(_ pattern: String, options: NSRegularExpression.Options = [],
                   markerGroups: [Int], contentGroup: Int,
                   font: NSFont? = nil, color: NSColor? = nil) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            re.enumerateMatches(in: text as String, range: range) { m, _, _ in
                guard let m = m else { return }
                let content = m.range(at: contentGroup)
                if let font = font, content.length > 0 { storage.addAttribute(.font, value: font, range: content) }
                if let color = color, content.length > 0 { storage.addAttribute(.foregroundColor, value: color, range: content) }
                for g in markerGroups {
                    let mr = m.range(at: g)
                    if mr.location != NSNotFound, mr.length > 0 { hide(mr) }
                }
            }
        }

        // Headings: `# ` … `###### ` → larger bold, hide the prefix.
        let headingScale: [CGFloat] = [1.7, 1.5, 1.3, 1.15, 1.05, 1.0]
        if let re = try? NSRegularExpression(pattern: "^(#{1,6})([ \\t]+)(.*)$", options: [.anchorsMatchLines]) {
            re.enumerateMatches(in: text as String, range: range) { m, _, _ in
                guard let m = m else { return }
                let level = m.range(at: 1).length
                let size = baseFont.pointSize * headingScale[min(level - 1, 5)]
                let hFont = fm.convert(NSFont.boldSystemFont(ofSize: size), toHaveTrait: .boldFontMask)
                let textRange = m.range(at: 3)
                if textRange.length > 0 {
                    storage.addAttribute(.font, value: hFont, range: textRange)
                    storage.addAttribute(.foregroundColor, value: theme.keywordColor, range: textRange)
                }
                hide(m.range(at: 1)); hide(m.range(at: 2))
            }
        }

        // Bold: **text** / __text__
        style("(\\*\\*)([^*\\n]+)(\\*\\*)", markerGroups: [1, 3], contentGroup: 2, font: bold)
        style("(__)([^_\\n]+)(__)", markerGroups: [1, 3], contentGroup: 2, font: bold)
        // Italic: *text* / _text_ (single delimiter)
        style("(?<![\\*])(\\*)([^*\\n]+)(\\*)(?![\\*])", markerGroups: [1, 3], contentGroup: 2, font: italic)
        style("(?<![_])(_)([^_\\n]+)(_)(?![_])", markerGroups: [1, 3], contentGroup: 2, font: italic)
        // Inline code: `code`
        style("(`)([^`\\n]+)(`)", markerGroups: [1, 3], contentGroup: 2, color: theme.stringColor)
        // Links: [text](url) → show text, hide brackets + (url)
        style("(\\[)([^\\]\\n]+)(\\]\\([^)\\n]+\\))", markerGroups: [1, 3], contentGroup: 2, color: theme.typeColor)

        // Tables: align columns, hide the |---| delimiter row, bold the header,
        // dim the pipes. Done last so inline cell styling is already applied.
        applyTableStyling(storage: storage, text: text, range: range,
                          baseFont: baseFont, boldFont: bold, theme: theme, hide: hide)
    }

    // MARK: - Tables

    /// Approximate rendered width of `s` in monospaced character cells, ignoring
    /// inline Markdown markers that get hidden (so column targets match what the
    /// user actually sees).
    private static func visualLength(_ s: String) -> Int {
        var t = s
        t = t.replacingOccurrences(of: "\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1",
                                   options: .regularExpression)
        for token in ["**", "__", "~~", "*", "_", "`"] {
            t = t.replacingOccurrences(of: token, with: "")
        }
        return t.count
    }

    private static func pipeOffsets(_ s: String) -> [Int] {
        let ns = s as NSString
        var offs: [Int] = []
        var k = 0
        while k < ns.length {
            if ns.character(at: k) == 124 { // '|'
                if k > 0, ns.character(at: k - 1) == 92 { k += 1; continue } // escaped \|
                offs.append(k)
            }
            k += 1
        }
        return offs
    }

    private static func isDelimiterRow(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.contains("-"), t.contains("|") else { return false }
        return t.allSatisfy { "|-: \t".contains($0) }
    }

    /// Detect Markdown table blocks (header row + `|---|` delimiter + body rows)
    /// and render them: align columns using `.kern` (works because the editor
    /// font is monospaced), collapse the delimiter row, bold the header, and dim
    /// the pipe separators. Operates on attributes only — the document text is
    /// never modified.
    private static func applyTableStyling(storage: NSTextStorage,
                                          text: NSString,
                                          range: NSRange,
                                          baseFont: NSFont,
                                          boldFont: NSFont,
                                          theme: SyntaxTheme,
                                          hide: (NSRange) -> Void) {
        let charWidth = ("0" as NSString).size(withAttributes: [.font: baseFont]).width
        guard charWidth > 0 else { return }

        var lines: [(range: NSRange, content: String)] = []
        text.enumerateSubstrings(in: range, options: [.byLines]) { sub, subRange, _, _ in
            lines.append((subRange, sub ?? ""))
        }

        var i = 0
        while i < lines.count {
            if i + 1 < lines.count,
               pipeOffsets(lines[i].content).count >= 2,
               isDelimiterRow(lines[i + 1].content) {
                var rowIndices = [i]
                var j = i + 2
                while j < lines.count {
                    let c = lines[j].content
                    if !c.trimmingCharacters(in: .whitespaces).isEmpty,
                       c.contains("|"), !isDelimiterRow(c) {
                        rowIndices.append(j); j += 1
                    } else { break }
                }
                styleTableBlock(storage: storage, lines: lines, rowIndices: rowIndices,
                                delimiterIndex: i + 1, boldFont: boldFont, theme: theme,
                                charWidth: charWidth, hide: hide)
                i = j
            } else {
                i += 1
            }
        }
    }

    private static func styleTableBlock(storage: NSTextStorage,
                                        lines: [(range: NSRange, content: String)],
                                        rowIndices: [Int],
                                        delimiterIndex: Int,
                                        boldFont: NSFont,
                                        theme: SyntaxTheme,
                                        charWidth: CGFloat,
                                        hide: (NSRange) -> Void) {
        struct Cell { let range: NSRange; let visualLen: Int }

        var rows: [[Cell]] = []
        for idx in rowIndices {
            let lineRange = lines[idx].range
            let content = lines[idx].content as NSString
            let offs = pipeOffsets(lines[idx].content)
            guard offs.count >= 2 else { rows.append([]); continue }
            var cells: [Cell] = []
            for k in 0..<(offs.count - 1) {
                let start = offs[k] + 1
                let len = max(0, offs[k + 1] - start)
                let regionRange = NSRange(location: lineRange.location + start, length: len)
                let inner = content.substring(with: NSRange(location: start, length: len))
                cells.append(Cell(range: regionRange, visualLen: visualLength(inner)))
            }
            rows.append(cells)
        }

        let colCount = rows.map { $0.count }.max() ?? 0
        guard colCount > 0 else { return }
        var targets = [Int](repeating: 0, count: colCount)
        for r in rows {
            for (c, cell) in r.enumerated() where c < colCount {
                targets[c] = max(targets[c], cell.visualLen)
            }
        }

        for (rowPos, idx) in rowIndices.enumerated() {
            let isHeader = rowPos == 0
            let lineLoc = lines[idx].range.location
            for off in pipeOffsets(lines[idx].content) {
                storage.addAttribute(.foregroundColor, value: theme.commentColor,
                                     range: NSRange(location: lineLoc + off, length: 1))
            }
            for (c, cell) in rows[rowPos].enumerated() where c < colCount {
                if isHeader, cell.range.length > 0 {
                    storage.addAttribute(.font, value: boldFont, range: cell.range)
                }
                let pad = targets[c] - cell.visualLen
                if pad > 0, cell.range.length > 0 {
                    let lastChar = NSRange(location: cell.range.location + cell.range.length - 1, length: 1)
                    storage.addAttribute(.kern, value: NSNumber(value: Double(pad) * Double(charWidth)),
                                         range: lastChar)
                }
            }
        }

        // Dim the delimiter pipes, then collapse the whole row (hide() leaves it
        // visible when the caret is on it, so it stays editable).
        let delimLoc = lines[delimiterIndex].range.location
        for off in pipeOffsets(lines[delimiterIndex].content) {
            storage.addAttribute(.foregroundColor, value: theme.commentColor,
                                 range: NSRange(location: delimLoc + off, length: 1))
        }
        hide(lines[delimiterIndex].range)
    }
}
