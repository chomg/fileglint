# RFC 0002 Comment-preserving formatting

Status: Selected for implementation; verification tracked in [issue #1](https://github.com/chomg/fileglint/issues/1)

## Context

The user requires comments to remain in Prettified YAML and TOML. The
bootstrap serializers retain data values but discard source comments and
can normalize aliases, quoting and order. Reattaching discarded comments
after serialization cannot reliably preserve their relationship to entries.
Issue #1 is the authoritative requirements and acceptance record. This RFC
records the implementation decision, not a second acceptance list.

## Decision

Format the original source with bounded whitespace edits instead of
re-emitting a parsed data model. Continue using the locked Yams and TOMLKit
parsers for validity. Keep JSON's existing lexeme-preserving formatter.

For YAML, consume every document through Yams and collect parsed node start
positions. Normalize horizontal gaps after a colon, comma or sequence dash
only when they immediately precede a parsed node on the same line. Convert
Yams's one-based Unicode scalar positions to UTF-8 source offsets; do not
confuse these with UTF-16 AppKit ranges. Deduplicate container positions
when walking aliases, since Yams resolves an alias to its anchor's node.
Keep the alias's original spelling and do not serialize or expand it.

For TOML, validate the source with TOMLKit, then normalize horizontal spaces
around assignments and after commas outside strings/comments. A small
lexical pass treats quoted keys, basic/literal strings, multiline strings
and comments as opaque ranges. It accounts for basic-string escapes and
four/five-quote multiline endings. Share these ranges with TOML highlighting
so the formatter and text view agree about comment/string boundaries.
The lexical pass does not decide whether TOML is valid.

Neither path moves or rewrites comments, scalar contents, document
separators, table headers, line breaks or indentation. A standalone comment
stays standalone and an inline comment stays on its original line. Already
spaced documents can remain identical in Prettified. Whitespace around
comments, including trailing spaces, is retained. The leading BOM is
omitted only from Prettified, as before; Raw remains exact decoded input.

## Tradeoffs and boundaries

YAML flow collections remain flow collections. TOML inline tables remain
inline tables. This deliberately replaces bootstrap layout canonicalization
with spacing normalization that preserves source fidelity. It does not
promise a standard two-space indentation style or expanded collections.
Do not use Raw fallback to evade ordinary comment-bearing input.

The existing input, formatting complexity and output caps remain. Parsing
errors and limits retain Raw with an explanation, without publishing a
partially formatted result. No dependency versions, sandbox permissions,
file associations or source bytes change. Folding and application picking
remain separate issues.

## Validation and follow-up

Compare parsed input/output semantics independently of explicit line-by-line
comment and literal-content checks. Cover streams, tags/aliases, block and
multiline strings, Unicode, quote runs, BOM/CRLF, empty/comment-only input,
invalid/limit cases and source-file immutability. AppKit checks exercise
mode restoration, colors and actual text-selection export in both
appearances. Actual Finder checks remain separate from component tests.
Record results and unavailable targets in the issue and PR.

This source-based representation also provides a foundation for the
separate [Prettified folding issue](https://github.com/chomg/fileglint/issues/2);
it does not implement or specify folding ranges.
