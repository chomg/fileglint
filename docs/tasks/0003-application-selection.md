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

On macOS 27.0.1 arm64 / Xcode 27.1, 34 Swift Testing tests passed. The required
local scope passed checks, tests, shared compilation and the universal native
host/extension/launcher build. Reports and final head-specific hosted evidence
will be linked in the issue/PR. Native synthetic-sample UI journeys also assert
that real-file opening controls are not hittable; the hosted matrix owns this
suite because this host's existing XCTest automation limitation is unchanged.

The feasibility experiment's seven Finder journeys remain evidence for the
architecture, not acceptance of this production candidate. Production Finder
validation must exercise the actual header controls and signed nested launcher,
compare app menus/defaults, verify original target document URLs and unchanged
hashes/defaults, check keyboard/Escape/light/dark and invalid Raw, and test a
temporary app registration/removal. The desktop locked before the initial
product-button check; the user has been asked to unlock. Do not recast missing
controls in a locked session as a product pass/failure.

## Next executable step

Finish current-candidate Finder validation and required hosted arm64/Intel CI,
record their actual results in issue #3, self-review and create this issue's PR.
The task is not finished and no production UI acceptance is claimed yet.
Minimum-macOS/Intel Finder coverage remains a release validation requirement.
