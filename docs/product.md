# Fileglint — Product Requirements

Fileglint is the product name; `fileglint` is the repository name. The name accommodates future file formats; the first slice remains JSON, YAML and TOML. See [the naming decision](decisions/0002-product-name.md).

## Users and problem

Mac developers and people inspecting configuration files need to read JSON, YAML and TOML quickly in Finder without launching an editor or changing the file.

## First usable outcome

Install a small containing app, enable its Quick Look extension if macOS requests it, select a `.json`, `.yaml`, `.yml` or `.toml` file in Finder, and press Space. Read selectable, syntax-colored text and switch between Raw and Prettified. Use Quick Look's native Open action for the default application; use Finder's Open With menu for other installed applications.

The host app provides setup instructions and a sample preview to diagnose rendering independently of Finder registration. It is not a document editor. The user agreed to the Quick Look + minimal host app approach on 2026-10-21.

## Initial scope

- Local UTF-8 files, including a leading UTF-8 BOM, up to 1 MiB. Prettification is available up to 128 KiB with nesting/indentation and a 4 MiB output cap; more complex files remain in Raw with an explanation.
- JSON, YAML streams and TOML parsed by established parsers; prettification remains in the original format. YAML/TOML comments, values, source order and line structure are preserved while spacing is normalized; Raw retains the original decoded text. See [comment-preserving formatting](rfcs/0002-comment-preserving-formatting.md) and its authoritative [issue #1](https://github.com/chomg/fileglint/issues/1).
- Read-only, selectable monospace text, native scrolling, system light/dark colors and keyboard-accessible mode controls.
- Invalid input remains available in Raw with a visible formatting error. Unsupported encodings, unreadable files and oversized files show actionable messages.
- No network use or source writes during previews. No default-file-association changes.

## Exclusions and next increments

No integration inside Apple Preview.app, editing/saving, thumbnails, schema validation, tree navigation, remote downloads, multi-gigabyte files, telemetry, or production distribution in bootstrap. A custom in-extension application picker is deferred until sandbox behavior is proven; the OS Open action and Finder Open With provide the initial workflow. Search and line numbers are useful follow-ups after native preview integration is verified.

## Targets and constraints

macOS 14 or later; Apple silicon and Intel. Native Swift/AppKit + QuickLookUI, sandboxed app and extension. Development builds are unsigned or ad hoc signed; Developer ID signing, notarization, App Store submission and installation outside the workspace require separate authorization. macOS controls extension routing and may require enabling it or resolving competing preview providers. Full Xcode is required for application/extension bundle verification; Swift command-line tools can run shared rendering/parser checks.

## Observable acceptance examples

| ID | Given / action | Observable result |
| --- | --- | --- |
| A1 | Select each supported fixture in Finder and press Space | This extension displays syntax-colored, selectable text; Escape closes it. |
| A2 | Preview compact JSON, flow YAML or inline TOML; switch Raw / Prettified / Raw | Readable same-format output; Raw restores exact decoded input and source bytes stay unchanged. |
| A3 | Preview malformed input | Raw remains readable, Prettified is disabled, and an error explains why. |
| A4 | Preview empty YAML, scalar JSON, Unicode, comments, YAML streams and TOML dates | No crash or silent loss of supported values; formatting is parser-valid. |
| A5 | Preview invalid UTF-8, missing file or more than 1 MiB | A clear error replaces the content; no stale prior document remains. |
| A6 | Open from Quick Look / Finder Open With | The original file opens in the chosen installed application; associations are unchanged. |
| A7 | Open host app and Try Sample; switch modes in light/dark appearance | Instructions and sample work, text remains legible and mode changes are accessible. |

Acceptance evidence and remaining gaps live in [task 0001](tasks/0001-bootstrap.md). A build or parser test alone does not establish Finder acceptance.
