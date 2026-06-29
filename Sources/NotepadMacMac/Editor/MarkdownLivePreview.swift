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
    }
}
