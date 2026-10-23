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

## Verification

Product-source candidate `05feda6d74d0d32a83828045012f42c498a7872c` passed the
complete local scope on macOS 27.0.1 arm64 / Xcode 27.1: 35 Swift Testing tests,
shared compilation, universal host/extension/launcher builds and the real signed
sandboxed launcher round trip. Retained report:
`.git/ai-dev-harness/runs/20261022T125435Z-ae7a7305/run.json`.

[Hosted ARM64 and Intel CI passed](https://github.com/chomg/fileglint/actions/runs/39782919465)
at that commit. Downloaded aggregate reports and numbered logs confirm all six
steps, 35 tests, the real launcher round trip and two HostUITests with no failures
on each architecture. Synthetic samples omit real-file opening. Evidence:
ignored `artifacts/issue3-ci-bootstrap/`.

Actual production Finder validation passed ten opening journeys across JSON,
YAML, `.yml` and TOML, including different defaults, alternatives and invalid Raw.
Target Xcode/TextEdit windows exposed the exact original document URLs. All four
menus/defaults matched native Finder. A temporary compatible sandboxed app
cold-launched; registration/removal refreshed the menu and a removed selection
showed an actionable error. Missing-source error and live JSON-to-TOML navigation
passed. Both appearances passed Prettified comment visibility, copy and Raw
restoration. Original hashes/defaults were unchanged. These are actual product
controls and signed nested launcher results, separate from the earlier probe.
Evidence: ignored `artifacts/issue3-validation/finder-summary.json`, individual
menu/target records, `finder-product5.log` and `finder-boundaries.log`.

This validation exposed a sandbox denial while inspecting the enclosing extension
signature. A bounded bundle-bookmark bootstrap now permits inspection of only
that exact bundle, then returns an authenticated anonymous endpoint. The
bootstrap cannot open files. Only the second, mutually authenticated channel
receives the source bookmark. The normal build check now exercises this real
boundary without registering apps or launching a target application.

## Accepted keyboard behavior — 2026-10-23

The user confirmed physical arrow/Return operation after opening the menu, and
Escape cancellation: first closes the menu, next closes Quick Look. Ordinary Tab
from Finder continues navigating Finder files instead of entering the preview
controls. AX labels/actions alone do not establish keyboard-only entry.

Temporary experiments with root view/controller containment, first responders,
initial responders, key-window requests and key equivalents did not establish
entry. They were removed; no focus-stealing or ineffective shortcut change is
part of the candidate. Finder owns the host window/event routing. Internal
first-responder success did not make the service window key; Tab still produced
new Finder preview requests.

The Mac's Keyboard Navigation was enabled, while the separate Accessibility >
Keyboard > Full Keyboard Access option was initially off. On 2026-10-23 the user
confirmed that keyboard operation works after enabling Full Keyboard Access.
After discussing ordinary Tab entry, the user accepted retaining this
implementation and leaving Full Keyboard Access to personal preference. This
supersedes the earlier request to resolve entry independently of that setting.
The accepted keyboard path requires Full Keyboard Access; ordinary Tab entry
with it disabled is not delivered. README, product/development guidance and
RFC 0003 describe the condition. Do not disable the user's current accessibility
preference during further validation.

Reinspection of the installed public QuickLookUI headers and Apple's
[QLPreviewingController documentation](https://developer.apple.com/documentation/quicklookui/qlpreviewingcontroller)
found preview-preparation callbacks, but no documented host-to-extension
keyboard-focus handoff hook. AppKit's key-view chain is already configured in
the product. Together with the failed first-responder experiments, this points
to host event routing as the current obstacle; it does not establish that every
public implementation approach is impossible. A reliable ordinary Tab solution
has not been demonstrated. The documented OS accessibility path was explicitly
accepted by the user, rather than counted as independent ordinary Tab support.

## Automation safety and cleanup

A later synthetic Tab/search/Return/Space probe reached Finder's Rename action
instead of the accessibility search UI, affecting only a newly created, ignored
keyboard-test fixture. The duplicate-name dialog was dismissed and the original
recorded fixture paths/hashes were reverified unchanged. Automatic Cmd-Y was
subsequently rejected by approval review because misrouted keyboard input could
manipulate a rename UI again. Do not retry that input or bypass the rejection;
wait for the user's actual keyboard verification. No change to keyboard-access
settings remains from the automated probes.

The temporary compatible validation app was unregistered, its owned process
stopped, and its bundle retained with a `.app.disabled` suffix to prevent
rediscovery. Catalogs no longer contain it; all four system defaults remained
unchanged. The normal development provider is retained. No unrelated app process
or provider was changed.

## Delivery

Keyboard acceptance now combines the user's actual Full Keyboard Access result,
their native menu/escape results and the documented accepted setting condition.
No new behavior code was added after product-source commit `05feda6`. Final
self-review covered the application catalog, UI state/stale guards, signed XPC
bootstrap/request boundaries, source immutability and native regression checks.
The significant implementation/security/integration commits are retained; no
shared history was rewritten. The final local scope passed again on 2026-10-23:
all four steps, 35 tests, universal binaries and the signed sandboxed launcher
round trip. Report: `.git/ai-dev-harness/runs/20261023T002812Z-ff2dfa0e/run.json`;
log: `artifacts/issue3-final-local-authorized.log`. This covers the unchanged
product code and final user-facing keyboard documentation; subsequent handoff
edits only record the result. The PR link and final hosted candidate results
belong on the authoritative issue/PR. Minimum-macOS/Intel Finder coverage remains
a not-run release validation requirement.
