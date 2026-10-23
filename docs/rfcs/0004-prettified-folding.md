# RFC 0004 Folding in Prettified previews

Status: implementation started; structural model first. Authoritative scope:
[issue #2](https://github.com/chomg/fileglint/issues/2). Folding is limited to
Prettified. Raw and original files remain unchanged.

## Source and presentation boundaries

Keep the full formatted text as the source of truth. PreviewCore supplies
immutable structural regions in UTF-16 coordinates, matching AppKit text ranges.
A region identifies its complete container, the interior that may be hidden,
its kind and nesting depth. IDs are source offsets within one document; they
are not persistent identities. Ranges are created only after successful bounded
formatting and refer to that exact formatted string, not Raw offsets.

PreviewUI will own disclosure controls, focus and layout. It must retain a
mapping from displayed positions to the complete formatted text if placeholders
replace hidden content. Copying a logical selection across a fold includes the
hidden source, and Select All copies the complete formatted document. Neither
disclosure labels nor placeholder text are copied. Glyph hiding that preserves
the underlying text is also possible, but must be verified for native selection,
scrolling and accessibility before choosing the presentation implementation.

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

YAML must use parsed mappings/sequences and source marks; resolved aliases must
not create duplicate ranges at their anchors. Document separators and scalar
contents cannot be interpreted as container syntax. Flow collections and block
containers need distinct range handling. Boundary comments belonging to a
following sibling/document stay outside the earlier fold.

TOML extraction must protect strings/comments using the existing source lexer
after TOMLKit validation. Distinguish table headers, array-of-table entries and
multiline arrays from brackets inside strings. Parent/child table names are
structured key paths, not plain dotted-string prefixes. Subsequent array-of-table
entries and their preceding comments must remain distinct.

YAML/TOML range extraction is not delivered by the initial JSON structural
slice. Do not infer completeness from the shared region type or advertise a
folding UI before the format-specific extraction and presentation are verified.

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

The normal local gate and both hosted architecture targets are required before
the issue's PR is ready. New UI behavior is not verified by this initial core
slice, and no issue acceptance checkbox is complete solely from its unit tests.
