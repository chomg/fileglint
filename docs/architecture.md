# Architecture and Code Boundaries

## Structure and responsibilities

- `Sources/PreviewCore/`: bounded file reads, format selection, parser validation, formatting and syntax ranges. Foundation + locked Yams/TOMLKit dependencies. No AppKit, network, persistence or source writes.
- `Sources/PreviewUI/`: shared AppKit controller, segmented mode control, selectable read-only NSTextView, dynamic system colors and inline failures.
- `Sources/PreviewOpening/`: macOS application discovery/catalogs, ephemeral source bookmark validation, the XPC client/protocol and signature trust. No file writes, default-association changes or persistent choices.
- `Sources/PreviewLauncher/`: separately sandboxed, on-demand XPC service embedded in the preview extension. Authenticates the enclosing extension signature, resolves the current file bookmark and opens only a freshly validated compatible application.
- `Sources/PreviewExtension/`: native QLPreviewingController. Reads/parses off the main thread, closes files promptly and displays the result on the main thread. Request identity prevents stale results from overwriting a newer preview.
- `Sources/PreviewHost/`: minimal setup window and sample preview. No document handler or background service.
- `Configuration/`: imported content types, preview extension declaration and sandbox entitlements. All application integration stays outside the formatter. The content-header split control and native OS Open action coexist.
- `Tests/`: Swift Testing parser and real AppKit component checks. `UITests/`: Xcode-hosted application journeys.
- `Fixtures/`: synthetic supported and invalid samples. No user data.
- `Package.swift` and `Package.resolved`: shared libraries and diagnostic executable. `Fileglint.xcodeproj`: native containing app, embedded extension and UI tests. `scripts/generate_project.py` deterministically maintains its project and scheme; edit the generator and regenerate together.

## Data and interfaces

PreviewDocument is an immutable-input value with Raw, optional Prettified and optional formatting error. Input is at most 1 MiB; formatting is at most 128 KiB input, nesting/indentation is bounded, and output is capped at 4 MiB. Larger supported text stays readable in Raw. Raw preserves decoded input, including BOM and line endings. Formatting is an in-memory representation; JSON retains lexemes. YAML/TOML formatting edits original source spacing while preserving comments, scalar spellings, order, indentation and line structure. Yams node marks identify YAML formatting boundaries; a TOML lexical pass protects strings/comments after TOMLKit validation. See [RFC 0002](rfcs/0002-comment-preserving-formatting.md).

Text is attributed native text, not evaluated code or HTML. No settings database, server, telemetry, network preview access, migrations or stored document cache exist. Dependencies are downloaded during setup only.

## Platform ownership

Single macOS product, macOS 14+, arm64/x86_64. No cross-platform adapters are needed. Universal verification, signed development and UI-test artifacts have separate derived-data directories so test-injected entitlements cannot be mistaken for production sandbox behavior. Quick Look supplies temporary access to the requested file. The host and extension are sandboxed separately. Installing/enabling/routing an extension is macOS-owned; shared tests and the diagnostic sample cannot prove Finder integration.

## Decisions

See [ADR 0001](decisions/0001-development-environment.md), [product naming](decisions/0002-product-name.md), [RFC 0001](rfcs/0001-structured-preview.md) and [bootstrap evidence](tasks/0001-bootstrap.md).

Application selection follows [RFC 0003](rfcs/0003-open-with-applications.md). Source/query identities prevent stale menus or delayed discovery from launching another document. XPC peers enforce designated code-signing requirements derived from their signed embedded bundles. Both retain App Sandbox. A bounded bootstrap bookmark permits read access to the exact enclosing extension for signature inspection; that protocol cannot open files. It returns an anonymous endpoint configured with the extension's signature requirement. The source bookmark is sent only through the mutually authenticated opening connection, and its access is released after opening.
