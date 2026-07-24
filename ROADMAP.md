# Roadmap

This file tracks what's planned for NotepadMacMac beyond
[v1.0.0](https://github.com/boschma1/NotepadMacMac/releases/tag/v1.0.0).
Each item is also a public issue on GitHub so you can follow progress,
comment, or pick one up.

The active milestone is
[**v1.1.0**](https://github.com/boschma1/NotepadMacMac/milestone/1).

## Shipped in v1.5.0

See the [v1.5.0 release notes](https://github.com/boschma1/NotepadMacMac/releases/tag/v1.5.0).

- **Rendered Markdown tables** in the live preview — columns are aligned,
  the `|---|` delimiter row is hidden, the header row is bold, and the
  pipe separators are dimmed. Alignment is done purely with text
  attributes (kerning on the monospaced editor font), so the underlying
  `.md` file is never rewritten. Put the caret on a table row to edit its
  raw Markdown; move away and it re-aligns.

## Shipped in v1.4.0

See the [v1.4.0 release notes](https://github.com/boschma1/NotepadMacMac/releases/tag/v1.4.0).

- **Obsidian-style live Markdown preview** — headings, bold, italic,
  inline code, and links render inline; the `#`/`**`/backtick/link
  markers collapse out of view and reveal only on the caret's line.
  Toggle with View → Markdown Live Preview (⇧⌘M).
- **Homebrew cask** — install with `brew tap boschma1/notepadmacmac &&
  brew install --cask notepadmacmac`. A release workflow auto-bumps the
  cask checksum on every release.

## Shipped in v1.3.0

See the [v1.3.0 release notes](https://github.com/boschma1/NotepadMacMac/releases/tag/v1.3.0).

- [**Developer ID signing + notarization**](https://github.com/boschma1/NotepadMacMac/issues/2)
  — the release `.app` is signed with the official Developer ID
  Application certificate, runs under the hardened runtime, and is
  notarized + stapled by Apple. No more Gatekeeper warning, no more
  `xattr -dr com.apple.quarantine` workaround.
- Release tooling: `scripts/release.sh` integrates signing,
  notarization, and stapling end-to-end.

## Shipped in v1.2.0

See the [v1.2.0 release notes](https://github.com/boschma1/NotepadMacMac/releases/tag/v1.2.0)
for the full feature list. Highlights:

- [**Universal (arm64 + x86_64) build**](https://github.com/boschma1/NotepadMacMac/issues/1)
  — release binary now runs natively on Intel Macs too
- Window transparency / opacity (Settings → Appearance)
- Several split-view fixes (right pane scrollable; word-wrap syncs both
  panes; window resize splits width equally)
- `=rand(p)` / `=rand(p, s)` Lorem Ipsum expansion on Enter (Word-style)
- "Developed by Markus Bosch" credit in the About panel
- Line-number gutter realigns correctly when toggling word wrap

## Shipped in v1.1.2

See the [v1.1.2 release notes](https://github.com/boschma1/NotepadMacMac/releases/tag/v1.1.2).

- Working Find & Replace (Cmd+F)
- Show Formatting Characters toggle (Cmd+Shift+I)

## Shipped in v1.0.0

See the [v1.0.0 release notes](https://github.com/boschma1/NotepadMacMac/releases/tag/v1.0.0)
for the full feature list. Highlights:

- Multi-tab editor with drag-to-reorder, drag-out-to-new-instance, split view
- Session restore (tabs + unsaved scratch content)
- Find / Replace, Find in Files, Go to Line
- Function List, Document Map, Folder workspace, Document List panels
- Macro recorder, word completion, per-tab word wrap, indentation detection
- Syntax highlighting for 15 languages
- Theme manager, Shortcut Mapper, User Defined Language editor
- Recent Files, single-instance behavior, plain-text clipboard

## Planned (v1.1.0)

| #   | Item                                                                                          | Area          |
| --- | --------------------------------------------------------------------------------------------- | ------------- |
| [#1](https://github.com/boschma1/NotepadMacMac/issues/1) | Universal (arm64 + x86_64) build (✅ shipped in v1.2.0) | Distribution  |
| [#2](https://github.com/boschma1/NotepadMacMac/issues/2) | Developer ID signing + notarization (✅ shipped in v1.3.0) | Distribution  |
| [#3](https://github.com/boschma1/NotepadMacMac/issues/3) | Homebrew cask (✅ shipped in v1.4.0)        | Distribution  |
| [#4](https://github.com/boschma1/NotepadMacMac/issues/4) | Document the plugin API                    | Plugins       |
| [#5](https://github.com/boschma1/NotepadMacMac/issues/5) | More built-in language definitions         | Languages     |
| [#6](https://github.com/boschma1/NotepadMacMac/issues/6) | Add an automated test suite                | Tests         |

### Notes

- **Universal binary** unblocks Intel Mac users; shipped in v1.2.0.
- **Signing + notarization** removed the Gatekeeper warning on first
  launch and is a prerequisite for the Homebrew cask; shipped in
  v1.3.0.
- **Homebrew cask** ships via the `boschma1/homebrew-notepadmacmac`
  tap (`brew install --cask notepadmacmac`); the cask checksum is bumped
  automatically on each release. Shipped in v1.4.0.
- **Plugin API documentation** turns the existing `PluginManager`
  extension point into something third parties can target safely.
- **More languages**: HTML / XML / YAML / TOML / plist / GraphQL /
  JavaScript / TypeScript / JSX / TSX / C / C++ / Objective-C /
  Lua / Perl / R / Scala / Groovy. These are recognized by file
  extension today but don't have first-class syntax definitions.
- **Tests**: a `swift test` target plus a GitHub Actions workflow.

## Ideas / not yet scheduled

These are things that have been mentioned but aren't on a milestone yet.
Open an issue if you want to push any of them up the list.

- Multi-cursor / column-selection editing
- LSP integration for real code intelligence
- Built-in terminal panel
- Git status decorations in the folder workspace
- Settings sync across Macs
- Linux / Windows builds (would require a non-AppKit UI layer)

## Contributing

If you'd like to take on a roadmap item, comment on the issue first so
we can discuss the approach and avoid duplicate work. Smaller fixes and
typos can go straight to a pull request.
