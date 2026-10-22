# Decision 0002 Product Name

Status: Accepted — 2026-10-22

## Context

The user chose `fileglint` in this chat. Future format support should not be constrained by the structured-text working name. The product is local and unpublished, with no released identity or Git remote to migrate.

## Decision

- Display the product as **Fileglint**; use **fileglint** for the repository name.
- Use `Fileglint.xcodeproj`, shared scheme/host target `Fileglint`, and embedded target `FileglintExtension`. Bundles are `Fileglint.app` and `FileglintExtension.appex`.
- Use development bundle IDs `dev.fileglint.Fileglint`, `dev.fileglint.Fileglint.PreviewExtension`, `dev.fileglint.HostUITests`, and `dev.fileglint.SampleHost` for the diagnostic host. Keep the extension ID prefixed by the containing app ID. These are development identifiers, not evidence of domain ownership or production signing registration.
- Keep internal PreviewCore/PreviewUI/PreviewHost/PreviewExtension module names and the structured-preview RFC URL: they describe responsibilities and the initial feature, independently of branding.
- The workspace folder is `/path/to/fileglint`, renamed from `macos-previewer` at the user's explicit request on 2026-10-22. Build paths derive from the checkout; historical evidence may retain its original absolute paths.

## Consequences

No preview formats, associations, permissions or signing policies change. Historical evidence and existing build artifacts retain their old names. Sample fixture branding changes intentionally, so previous fixture hashes describe the earlier files only.

The development ID is a separate macOS extension identity. Previously
registered Structured Preview builds may still appear until explicitly
disabled/unregistered. Verify routing and acceptance when implementation
is installed; enabling and provider selection are macOS-owned. Record
actual results in [task 0001](../tasks/0001-bootstrap.md). Do not change
unrelated providers or default associations.

At the naming decision there was no hosted project, release, Homebrew
cask or App Store record to rename. Creating/publishing those is separate
work. No availability or trademark clearance is implied.
