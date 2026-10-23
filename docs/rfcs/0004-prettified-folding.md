# RFC 0004 Folding in Prettified previews

Status: implemented; acceptance validation in progress. Authoritative scope:
[issue #2](https://github.com/chomg/fileglint/issues/2). Folding is limited to
Prettified. Raw and original files remain unchanged.

## Source and presentation boundaries

Keep the full formatted text as the source of truth. PreviewCore supplies
immutable structural regions in UTF-16 coordinates, matching AppKit text ranges.
A region identifies its complete container, the interior that may be hidden,
its kind, control position and nesting depth. IDs derive from source positions
and representation within one document; they are not persistent identities.
Ranges are created only after successful bounded
formatting and refer to that exact formatted string, not Raw offsets.

PreviewUI owns disclosure controls, focus and layout. FoldProjection retains
explicit mappings from displayed spans to complete formatted source. The chosen
presentation inserts attachment spaces with native NSButton overlays and replaces
collapsed interiors with an ellipsis. Root block YAML uses a synthetic Mapping or
Sequence heading to distinguish document and first-child controls. Copying a
logical selection across a placeholder includes its complete hidden source, and
Select All copies the complete document. Labels and attachment spaces have no
copied source. Literal source ellipses/object-replacement characters are ordinary
source spans and are never removed by a text-search replacement rule.

Controls follow a block heading or opening delimiter so they do not shift keys
or data indentation. Whole block containers receive a synthetic type heading;
compact sequence entries preserve the original column on the next display line.
All added heading text/padding has an empty copied source range.

Only visible controls receive button views; scrolling/resizing updates their
glyph coordinates and key-view chain. Each button has a section/line label and
expanded state. With the text focused, Command-Option-Left collapses the section
at the cursor and Command-Option-Right expands it. Finder keyboard entry uses the
same Full Keyboard Access setting as the existing Open controls. No global key
monitor, focus stealing, Escape override or system preference change is added.

Fold state is an in-memory value for one Prettified session. A parent hides its
descendants' controls without deleting their collapsed states. Reopening the
parent restores those states. Loading a document or switching modes creates a
fresh expanded session. Invalid and over-limit previews have no regions.

## Structural extraction

For JSON, scan the already validated formatted representation, tracking quoted
strings and escapes before matching object/array delimiters. This preserves
duplicate keys, number and string spellings, and UTF-16 positions without
re-serializing the data model. Non-empty containers, including a root array,
receive regions. Empty containers and scalars receive none.

YAML uses parsed mappings/sequences and Unicode-scalar source marks. Original
syntax at each mark determines flow versus block representation; composed-node
style metadata is not assumed to retain the source spelling. Quote/block-scalar
spans protect data and document-like text. Visit each physical container once,
before materializing children; aliases cannot duplicate or repeatedly expand
anchor ranges. Block sections retain their heading. Boundary blank/comment runs
at the sibling indentation remain outside the previous fold, while more-indented
interior comments and protected scalar lines stay attached. Stream separators
and between-document comments are never folded into the preceding document.

Resolved aliases do not supply their occurrence marks. Block entry boundaries
therefore follow physical indentation rather than the next resolved node mark;
an anchor's fold cannot absorb sibling alias entries. Alias keys recover their
physical heading from the value's source position. A block mapping and its first
structured key can share a start mark, so their range identities distinguish the
source representation. Controls in a retained structured heading remain visible;
only anchors within actually hidden interiors are suppressed.

TOML protects strings/comments with the existing source lexer after validation.
Bracket depth distinguishes headers from multiline array rows. TOMLKit decodes
isolated header key paths, so quoted dots and escape spellings have the right
hierarchy. Compare decoded UTF-8 key bytes rather than Swift's canonical String
equality: distinct NFC/NFD names stay separate while equivalent escape spellings
refer to the same key. A source-order stack closes tables before unrelated/sibling headers
or the next array-of-table entry. Leading boundary comments stay visible with
the following section. Only contiguous descendant sections belong to a table
fold; later descendants beyond an unrelated table retain separate controls.
Non-empty array/inline-table interiors use delimiter ranges outside opaque spans
and header lines. Comment-only empty arrays have no control.

## Bounds and validation

Retain the existing 128 KiB formatting input, 4 MiB output and complexity caps.
Range extraction works on the bounded formatted output; session visibility
walks ordered regions without recursively expanding aliases or rescanning a
subtree for each control. Source text is never removed from the document model.

Core checks exercise strings/escapes, Unicode coordinates, nested and empty
containers, root arrays, session visibility and retained child states. Remaining
checks must cover YAML/TOML scalars/comments/streams, source selection mapping,
mode/document resets, real AppKit controls and light/dark rendering. Actual host
and Finder journeys must separately establish keyboard access, copy, scrolling,
Escape and unchanged source bytes for all supported formats. Host accessibility
actions are not evidence that Finder receives ordinary Tab; the current OS
Full Keyboard Access condition must be reported when testing disclosure controls.

AppKit component suites share a serial parent and use off-screen owned windows
for deterministic layout without taking the user's key window. Actual host and
Finder interaction are separate evidence. The test adapter requires Swift
Testing's complete passing aggregate report as well as exit status, because an
on-screen command-line AppKit probe ended early with status zero. That early
probe is not counted as passed. The normal local gate and both hosted targets
are required before the issue's PR is ready.
