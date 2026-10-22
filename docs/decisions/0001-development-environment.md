# Decision 0001 Development Environment

Status: Accepted; native bundle/current Finder verified, automated UI and hosted verification pending

## Context

The user selected a Finder Quick Look extension packaged in a minimal containing app. This is a macOS integration product with no server, browser engine or persisted document model. The repository is initially a directory without Git metadata. This host has macOS 27.0.1 arm64, Swift 6.4 (swiftlang-6.4.0.34.1), SDK 27.0 and uv; full Xcode was initially absent. The user later authorized installation and completed first launch of App Store Xcode 27.1 (27A9275).

## Decision

Use native Swift/AppKit and QuickLookUI, minimum macOS 14, arm64 and x86_64, Debug and Release configurations. Use Swift tools version 6.0 with Swift 5 language mode for compatibility with the selected parsers. Native Xcode application and extension targets live in Fileglint.xcodeproj; a root Swift package provides shared libraries and local component tests. Sources and Tests follow SwiftPM layout. A package executable provides a local setup/sample rendering harness, not extension registration.

Use Foundation JSON validation, Yams 6.2.2 for YAML nodes/streams and TOMLKit 0.6.0 for TOML parsing/serialization, exact requirements and Package.resolved. Do not implement YAML/TOML parsers. Use a native NSTextView, without WebKit or JavaScript. The preview extension has App Sandbox enabled and receives file access from Quick Look. The host requests no document association or network entitlement.

Keep the direct workflow. uv launches the existing Python harness; a project Python adapter maps finite Swift/Xcode commands. Full Xcode 26.0.1 (Swift 6.2, SDK 26.0) is the CI toolchain; local work also supports Swift 6.4 CLT and the installed full Xcode 27.1. The latter has real local universal-build and Finder evidence, while the separate CI pin remains unexecuted here. CI targets macOS 15 arm64 and x86_64 separately. Universal bundle build checks both architectures; XCUITest runs natively on each runner. Oldest supported macOS 14 Finder acceptance remains a required manual compatibility check before release.

## Alternatives and tradeoffs

Electron/WebKit adds runtime and escaping concerns without helping native integration. A standalone viewer adds a second user workflow. Legacy qlgenerator plug-ins are not selected. SwiftUI remains an option for later settings; AppKit gives direct control over selectable colored text and QuickLookUI integration. Xcode owns native extension packaging; SwiftPM tests do not substitute for that build.

## Consequences

Full Xcode and a graphical macOS session with test automation authorization are needed for bundle/UI validation. Keep universal verification, signed development and UI-test derived data separate: Xcode injects extra entitlements into test builds. A development build with only the declared sandbox/debug entitlements is required for meaningful Finder sandbox acceptance. macOS selects the preview provider and users may need to enable the extension. Public distribution/signing decisions are deferred; no store or notarization credentials are needed for bootstrap. Custom in-extension app launching is deferred in favor of the native Open action and Finder Open With.

## Evidence

See [bootstrap evidence](../tasks/0001-bootstrap.md), [development commands](../development.md) and [preview RFC](../rfcs/0001-structured-preview.md). The containing-app approach was explicitly agreed in this chat on 2026-10-21; routine implementation and compatibility defaults were selected within the authorized bootstrap.
