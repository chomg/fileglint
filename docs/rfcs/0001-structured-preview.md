# RFC 0001 Read-only Structured Quick Look Preview

Status: Accepted for implementation; platform acceptance pending

## Objective and context

Implement the [first usable outcome](../product.md): inspect structured text through Finder Quick Look without editing it. Extension packaging, content-type routing, parser fidelity and sandbox boundaries warrant a design record.

## Scope, constraints and exclusions

Sources/PreviewCore owns bounded UTF-8 file loading, parser-driven formatting and lexical token ranges. Sources/PreviewUI owns the shared native text view and mode controls. Sources/PreviewExtension is a QLPreviewingController adapter; Sources/PreviewHost provides setup/sample UI. The extension reads off the main thread, closes the descriptor, then installs a completed result on the main thread. A request identity suppresses stale content if the controller is reused. Raw text is the default and the source is never written.

JSON is validated with Foundation; pretty output must preserve numeric/string lexemes rather than round-trip through floating-point values. YAML uses nodes rather than constructing arbitrary tagged objects or expanding aliases. TOML uses TOMLKit tables for validation. The bootstrap allowance to omit comments is superseded by [RFC 0002](0002-comment-preserving-formatting.md) and [issue #1](https://github.com/chomg/fileglint/issues/1): YAML/TOML now format original source spacing while preserving comments and line structure. Formatting failures retain Raw and disable Prettified. Input is capped at 1 MiB; formatting complexity and output limits protect responsiveness. Text is rendered directly, never interpreted as HTML.

Configuration/Host-Info.plist imports public JSON/YAML/TOML content types. The extension advertises the same identifiers, with .yaml/.yml sharing a type. No document handler is registered and the user's default application is untouched. The extension is embedded in the containing app's Contents/PlugIns. Xcode handles bundle assembly and development signing; production signing is separate.

No in-extension NSWorkspace application picker is promised without real sandbox evidence. The native Quick Look toolbar and Finder Open With cover opening the original file in bootstrap. No network, persistence, editor or thumbnails.

## Acceptance examples and executable mapping

| Criterion | Boundary | Check / flow | Target and evidence |
| --- | --- | --- | --- |
| A2/A4 same-format formatting, Unicode, streams, dates | PreviewCore | PreviewDocumentTests, semantic parser comparisons and source-byte checks | Native SwiftPM tests; actual results in task 0001 |
| A3 invalid input retains Raw | Core + UI | Malformed fixtures; disabled segment and visible error | SwiftPM core/AppKit tests + host XCUITest |
| A5 bounded reads and encoding failures | Core + UI | Exact-limit/over-limit, missing path, stale-content clearing | SwiftPM tests |
| A7 setup/sample, mode selection and copy | Host + UI | Host XCUITest and graphical review | Xcode macOS jobs; local actual execution separately recorded |
| A1 actual extension selection and lifecycle | Extension + OS | Finder fixtures, Space, modes, Escape; multiple-file navigation | Required manual interactive acceptance; not inferred from tests |
| A6 original file opened in default/other app | OS integration | Quick Look Open and Finder Open With | Required manual acceptance |

## Decisions and unknowns

See [ADR 0001](../decisions/0001-development-environment.md). macOS UTI routing, enabling the extension, competing providers, signed sandbox behavior and minimum-OS compatibility need actual platform evidence. A generated project or passing shared tests do not resolve them. Production distribution channel remains outside bootstrap.

## Independently verifiable slices

1. Shared read/format/render behavior, fixtures, unit and native control tests.
2. Host + embedded native extension, plist type declarations, Xcode bundle build and host XCUITest.
3. Installed extension Finder acceptance across supported OS and architectures. Record failures and routing conflicts before release; do not substitute harness UI evidence.

Each slice includes implementation and checks. [Task 0001](../tasks/0001-bootstrap.md) is the authoritative progress record.

## Rollout and verification

Run the baseline local scope and required CI at the candidate revision. CI builds both architectures and runs native unit/control/host UI tests on arm64 and x86_64. Retain logs and xcresult artifacts for 14 days. Manual installed Finder acceptance is required separately. No document migration is needed. Installation, production signing/notarization and publishing require separate authorization.
