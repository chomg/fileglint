# Comment preservation implementation handoff

Authoritative requirements and acceptance: [GitHub issue #1](https://github.com/chomg/fileglint/issues/1).
Design: [RFC 0002](../rfcs/0002-comment-preserving-formatting.md).
This record links to the scope rather than duplicating its acceptance list.

## Implemented behavior

YAML/TOML formatting now edits original source spacing, preserving comment
text, order and attachment to entries. It retains line structure, values,
tags, aliases, quoting, document/table order and Raw restoration. It no
longer canonicalizes YAML flow collections into block layout or rewrites
TOML tables through a serializer. The host's Try Sample offers JSON, YAML
and TOML so comment preservation can be inspected without Finder routing.

## Evidence and environment — 2026-10-22

Current execution host: macOS 27.0.1 (26A434), arm64, Swift 6.4, CLT selected.
Full Xcode and a usable graphical automation session are unavailable in this
execution environment. This differs from the earlier bootstrap host state;
historical successful Xcode/Finder results do not verify this candidate.
uv 0.12.19 was prepared under ignored `.build/tools`; the harness used the
installed Python 3.14 runtime without changing global tool selection.

The clean baseline at `dbee0d2` passed project checks, all 12 original tests
and shared compilation. The universal native bundle step failed because
full Xcode is absent. Its retained report is
`.git/ai-dev-harness/runs/20261022T052403Z-c65e7b27/run.json`.

The implementation's local aggregate report at
`.git/ai-dev-harness/runs/20261022T053240Z-9f734ec3/run.json` passed project
checks, 20 tests and shared compilation, then hit the same missing-Xcode
native-build failure. Tests cover explicit line-by-line comment placement,
independent parser semantics, BOM/CRLF, streams, tags/aliases, quoted/block
and multiline scalar contents, TOML four/five-quote endings, malformed and
boundary input, unchanged source bytes, AppKit mode restoration, colors
and real selection export to a separate pasteboard in both appearances.
The later alias-expansion regression and final candidate verification are
reported in the issue/PR alongside hosted results.

## Remaining validation and next executable step

Run the documented CI scope on both required native architecture jobs for
the candidate revision, including the new host YAML/TOML sample journey.
Record hosted run URLs and results in the issue/PR. The local aggregate is
not a pass, and component coverage is not Finder evidence.

On a Mac with full Xcode and a graphical session, build the development app
with `uv run --script scripts/dev.py build-development`, launch it from its
workspace output, and follow the Finder checklist using
`Fixtures/comments.yaml` and `Fixtures/comments.toml` (including a `.yml`
copy). Check comments, mode restoration, selection/copy, source hashes and
light/dark appearances. Record build identity, OS and architecture. Minimum
macOS 14 and other architecture Finder coverage remain required before
release; do not mark issue #1 fully accepted from CI alone.
