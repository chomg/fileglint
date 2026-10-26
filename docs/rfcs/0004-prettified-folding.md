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

PreviewUI owns a narrow, fixed left gutter with native NSButton disclosures.
It shares the document's vertical scroll position and has no line numbers.
Expanded display text is exactly the complete formatted source: no inline
attachments, synthetic Mapping/Sequence headings, padding or labels are inserted.
Collapsed interiors are replaced with an ellipsis. FoldProjection maps visible
source and placeholders to the immutable full text, so copying across a
placeholder includes all hidden content/comments and Select All copies the full
formatted document. Literal ellipses/object-replacement characters remain data.

The user approved this gutter redesign for PR #6 after reviewing the inline
presentation. There is no synthetic whole-document fold. Implicit YAML stream
mapping/sequence roots have no control; explicit root braces/brackets remain
actual foldable containers. Block sections preserve their first source line.
A logical source line has one arrow for its outermost starting container;
containers starting on their own lines get independent arrows. Wrapping keeps
the arrow on the first displayed row. Empty/scalar sections need no arrow.
The gutter receives mouse input independently of selectable text and never
contributes copied characters. Raw has no gutter or folding controls.

Only viewport controls receive button views; scrolling/resizing updates their
first-line coordinates and key-view chain. The gutter background and buttons
are siblings of the text in NSClipView, with a reserved text inset. Buttons
stay independent accessibility contents of FoldingScrollView with native
scroll-area parents and linear navigation order. This preserves the structure
that passed the user's physical Full Keyboard Access test; controls must not
be nested inside the atomic text accessibility element. Each button has a
section/line label and expanded state. Folding batches text replacement,
selection remapping and viewport restoration before updating native controls.
A final layout notification identifies the changed elements using the SDK
UI-elements payload, rather than announcing anonymous intermediate layouts.
Value notifications report the final expanded state. Borderless buttons use
an exterior focus ring.

With text focused, Command-Option-Left/Right collapse/expand the section at the
cursor. Finder keyboard entry uses the user-controlled Full Keyboard Access
setting, as with the existing Open controls. No global key monitor, focus
stealing, Escape override or system preference change is added. Native click
sequences remain native, including two actions for a double-click; no arbitrary
timing filter or repeated-click suppression is added. The user accepted this
choice on 2026-10-26 after the tested Mac's Full Keyboard Access converted rapid
Space presses into double-click sequences in both plain native and actual
folding controls. Physical Finder results and the host-specific diagnostic
limit are recorded in the [handoff](../tasks/0004-prettified-folding.md).

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
