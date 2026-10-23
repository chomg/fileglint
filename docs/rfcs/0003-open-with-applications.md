# RFC 0003 Application selection in previews

Status: implemented; placement and keyboard behavior accepted. Authoritative scope:
[issue #3](https://github.com/chomg/fileglint/issues/3). The user approved a
separate split control to the right of Raw/Prettified on 2026-10-22.

## Platform evidence and placement

The actual development-signed Finder extension can enumerate registered apps,
but direct Launch Services opening is denied (`allow lsopen` is absent).
`NSExtensionContext.open` also returned false. A separately sandboxed, embedded,
on-demand XPC service successfully opened original files when given ephemeral
URL bookmark data. Seven Finder journeys verified original document URLs in
Xcode/TextEdit, and all four extensions matched Finder's application lists.
The issue records the evidence and current-Mac coverage limits.

No supported Quick Look extension API for modifying Finder's native Open button
was found. Keep that OS action and place Fileglint's own control in the preview
content header. Main button opens the current default; the separate arrow lists
compatible apps. Samples have no source URL and omit opening controls.

The user accepted the existing keyboard behavior on 2026-10-23 after confirming
operation with macOS Full Keyboard Access enabled. In Finder, ordinary Tab with
that feature off continues file navigation. Keep native accessible buttons and
their key-view order, document this OS preference, and leave it under user
control. Independent Tab entry without Full Keyboard Access is not required by
the accepted scope. Internal first-responder/key-window experiments did not
establish a supported host-to-extension handoff and are not included.

## Boundaries and flow

`PreviewOpening` contains macOS app discovery, deterministic catalog labels,
request validation, the XPC protocol/client and signature trust. PreviewCore
continues to know nothing about applications or launching. PreviewUI owns the
split control and action state. FileglintLauncher is nested in the extension's
Contents/XPCServices and runs only on an explicit request.

Refresh discovery for each source and before presenting the menu or launching.
Deduplicate canonical application URLs, sort default first then name/path, and
include paths for same-name installations. No default still permits alternatives;
empty results explain the limitation. Separate opening status from parse status.

Each source and query has an identity. Discard late queries, cancel prior menu
tracking and pending client operations on navigation, and bind menu items to
the source/generation that created them. Revalidate a selected app against a
fresh catalog; never silently substitute a different app for a removed choice.
Bound discovery and launch waits and show failures inline.

## Sandbox and trust

Both the extension and launcher retain App Sandbox. Pass an ephemeral bookmark
only for the original file; persist nothing and release access after launching.
Resolve without UI/mounting, reject stale/mismatched paths, unsupported formats,
non-regular/unreadable sources, oversized bookmarks/paths and unregistered apps.
Opening never writes files or changes default associations.

Authenticate both XPC peers with the public macOS 13+ code-signing requirement
APIs. Derive each peer's requirement from its signed embedded bundle, rather
than relying on a process ID, hard-coded development team or unsigned fallback.
The helper cannot read its enclosing extension through its own sandbox. A
bootstrap connection therefore accepts a bounded ephemeral bookmark naming
only that exact enclosing bundle, validates its signature and returns an
anonymous endpoint with that requirement installed before accepting requests.
The bootstrap protocol has no file-opening method. The client authenticates the
helper on both connections, and sends the source bookmark only through the
second, mutually authenticated connection. All scopes/connections are released
when the request finishes or is cancelled.
The listener restricts peers to the enclosing extension's designated signature
and current user; the client restricts replies to its embedded launcher's
signature. This supports ad hoc development and normal distribution signatures.
No app group, login item, private API or broad filesystem exception is needed.

## Validation

Catalog/request tests cover normalization, ambiguous names, absent defaults,
invalid bookmarks/files/apps and trust failures. AppKit tests inject discovery
and opening to exercise actual controls, stale menus/queries/completions, missing
apps/files, errors/timeouts and both appearances. Native sample UI checks ensure
synthetic samples cannot open pretend files. Real Finder checks separately
verify arrow/menu/default/alternative actions, source identity, copying/modes,
keyboard/Escape and unchanged hashes/defaults with the signed sandboxed bundle.
Run the normal local gate and the required hosted arm64/Intel matrix. Current-Mac
Finder evidence does not establish minimum-OS/Intel Finder acceptance.
