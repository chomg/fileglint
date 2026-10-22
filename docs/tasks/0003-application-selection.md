# Application selection implementation handoff

Authoritative scope and acceptance: [issue #3](https://github.com/chomg/fileglint/issues/3).
Design: [RFC 0003](../rfcs/0003-open-with-applications.md). The user approved
content-header placement and a PR after verification on 2026-10-22.

## Delivered structure

PreviewOpening isolates application discovery, catalog ordering/labels,
per-file bookmark/request validation, XPC protocol/client and signature trust.
PreviewUI adds the separate default-action and arrow controls to the right of
Raw/Prettified. Query/source identities reject stale actions/results. Parse and
opening errors have separate status fields. Synthetic samples omit real-file
opening. The separately sandboxed FileglintLauncher is embedded in the preview
extension and authenticates its client using its enclosing extension signature;
the client likewise requires its signed embedded launcher. No source writes,
association changes, stored app choice or sandbox exception is introduced.

## Verification in progress

On macOS 27.0.1 arm64 / Xcode 27.1, 35 Swift Testing tests passed. The required
local scope passed checks, tests, shared compilation and the universal native
host/extension/launcher build. Reports and final head-specific hosted evidence
will be linked in the issue/PR. Native synthetic-sample UI journeys also assert
that real-file opening controls are not hittable; the hosted matrix owns this
suite because this host's existing XCTest automation limitation is unchanged.

The production Finder menu displays the registered default and alternatives, and
its TextEdit selection opened the original JSON (verified by the target window's
document URL). This exposed a sandbox denial while reading the enclosing bundle
for signature trust. The fix uses a bounded bundle-bookmark bootstrap with no
opening method, followed by an anonymous endpoint enforcing both peers' signed
requirements. The local gate now includes an actual sandboxed launcher round
trip that rejects an unregistered app without launching anything. This passed;
the earlier injected-only tests could not detect that integration failure.

Remaining current-candidate Finder checks cover all suffixes, menu parity,
normal/invalid sources, original target URLs, modes/copy and both appearances,
registration/removal, unchanged hashes/defaults and keyboard cancellation. Key
injection has not cancelled the remote menu, so physical Escape behavior has
been requested from the user. Do not count an unreceived automated key as a pass.

## Next executable step

Finish current-candidate Finder validation and required hosted arm64/Intel CI,
record their actual results in issue #3, self-review and create this issue's PR.
The task is not finished and no production UI acceptance is claimed yet.
Minimum-macOS/Intel Finder coverage remains a release validation requirement.
