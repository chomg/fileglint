# macOS Project Profile

Apply to macOS applications. Choose native Swift/AppKit/SwiftUI, a cross-platform framework, or another implementation according to system integration, distribution, and product requirements. Add the cross-platform profile when appropriate.

## Record during bootstrap

- Minimum supported macOS version, supported CPU architectures, selected IDE/SDK versions, and build configurations.
- Project, workspace, scheme, package, or framework entry points and dependency resolution files.
- Local launch procedure, unit tests, UI automation, test fixture locations, and build output paths.
- Required capabilities such as file access, notifications, accessibility, login items, or background execution when the feature uses them.

## Verification

For a native Xcode implementation, use a macOS host with the selected Xcode. Inspect the real schemes and destinations before writing command mappings; `swift test` alone does not cover every Xcode application. For another framework, use its supported commands and retain platform-specific verification.

Exercise the important desktop behaviors on the actual application: windows, menus, shortcuts, persistence, and permission or lifecycle transitions where relevant. UI automation may require an interactive desktop session and appropriate permissions. Document the runner limitations rather than treating unit tests as UI verification.

Isolate per-task build output and user data when multiple instances are run. System permissions and signing resources are not isolated just by creating a Git worktree.

## Release boundary

Keep local development builds separate from distribution signing, notarization, packaging, and store submission. Document the selected distribution channel and signing approach once chosen. Do not commit certificates or private keys.

References: [Apple command-line tools](https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference) and [Apple test results](https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results).
