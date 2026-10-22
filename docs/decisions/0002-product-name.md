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

The new development ID is a separate macOS extension identity. Previously registered Structured Preview builds may still appear until disabled/unregistered. Finder routing needs verification after migration; the current Mac's Fileglint JSON/mode journey and the project-only extension election changes are recorded in [bootstrap evidence](../tasks/0001-bootstrap.md#follow-up-fileglint-rename--2026-10-22). Earlier broader Finder checks apply to the previous identity. macOS may ask the user to enable Fileglint Preview in Quick Look extensions on other installations.

At the naming decision there was no Git repository, hosted project, release, Homebrew cask or App Store record to rename. The user subsequently authorized local Git initialization on main; remote creation and publication remain separate work. No availability or trademark clearance is implied by this decision.
