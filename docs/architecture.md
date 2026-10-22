# Architecture and Code Boundaries

## Structure and responsibilities

- `Sources/PreviewCore/`: bounded file reads, format selection, parser validation, formatting and syntax ranges. Foundation + locked Yams/TOMLKit dependencies. No AppKit, network, persistence or source writes.
- `Sources/PreviewUI/`: shared AppKit controller, segmented mode control, selectable read-only NSTextView, dynamic system colors and inline failures.
- `Sources/PreviewExtension/`: native QLPreviewingController. Reads/parses off the main thread, closes files promptly and displays the result on the main thread. Request identity prevents stale results from overwriting a newer preview.
- `Sources/PreviewHost/`: minimal setup window and sample preview. No document handler or background service.
- `Configuration/`: imported content types, preview extension declaration and sandbox entitlements. System Open actions stay outside the formatter.
- `Tests/`: Swift Testing parser and real AppKit component checks. `UITests/`: Xcode-hosted application journeys.
- `Fixtures/`: synthetic supported and invalid samples. No user data.
- `Package.swift` and `Package.resolved`: shared libraries and diagnostic executable. `Fileglint.xcodeproj`: native containing app, embedded extension and UI tests. `scripts/generate_project.py` deterministically maintains its project and scheme; edit the generator and regenerate together.

## Data and interfaces

PreviewDocument is an immutable-input value with Raw, optional Prettified and optional formatting error. Input is at most 1 MiB; formatting is at most 128 KiB input, nesting/indentation is bounded, and output is capped at 4 MiB. Larger supported text stays readable in Raw. Raw preserves decoded input, including BOM and line endings. Formatting is an in-memory representation; JSON retains lexemes, while YAML/TOML may normalize comments, quoting and layout.

Text is attributed native text, not evaluated code or HTML. No settings database, server, telemetry, network preview access, migrations or stored document cache exist. Dependencies are downloaded during setup only.

## Platform ownership

Single macOS product, macOS 14+, arm64/x86_64. No cross-platform adapters are needed. Universal verification, signed development and UI-test artifacts have separate derived-data directories so test-injected entitlements cannot be mistaken for production sandbox behavior. Quick Look supplies temporary access to the requested file. The host and extension are sandboxed separately. Installing/enabling/routing an extension is macOS-owned; shared tests and the diagnostic sample cannot prove Finder integration.

## Decisions

See [ADR 0001](decisions/0001-development-environment.md), [product naming](decisions/0002-product-name.md), [RFC 0001](rfcs/0001-structured-preview.md) and [bootstrap evidence](tasks/0001-bootstrap.md).
