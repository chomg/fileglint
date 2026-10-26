# Prettified folding implementation handoff

Authoritative scope and acceptance: [issue #2](https://github.com/chomg/fileglint/issues/2).
Design: [RFC 0004](../rfcs/0004-prettified-folding.md).

## Started slice — 2026-10-23

Branch `codex/collapsible-prettified` starts from main `9878e10`, the merge of
reviewed PR #5. PR #5's meaningful implementation/security commits were retained.
The source tree at that merge matches its verified PR head exactly. Its merge
review and final candidate evidence are recorded on PR #5; issue #3 is closed.

The first folding slice adds immutable UTF-16 structural ranges for non-empty
JSON objects/arrays after successful bounded formatting. A string/escape-aware
scan preserves literal spellings, duplicate keys and Unicode coordinates.
PreviewDocument carries the ranges alongside its unchanged Raw/Prettified text.
The new FoldSession value hides descendant regions under a collapsed parent
while retaining child states. Fresh sessions start expanded; no state persists.

Seven focused core tests cover nested/sibling containers, quoted delimiters and
escapes, Unicode offsets, empty/scalar values, root arrays, duplicate keys,
number/string spellings, BOM, invalid/limited fallback, nested state and 10,000
sibling containers. All 42 existing/new tests in six suites passed together;
log: ignored `artifacts/issue2-core-initial-test.log`.

The full local scope also passed: project/syntax checks, all 42 tests, shared
compilation, universal host/extension/launcher binaries and the real signed
sandboxed launcher round trip. Report:
`.git/ai-dev-harness/runs/20261023T005447Z-11eb638c/run.json`; log:
`artifacts/issue2-core-local.log`. Environment: macOS 27.0.1 arm64 / Xcode 27.1.
This verifies the structural slice, not a folding UI or its pending format paths.

At that initial revision (`8d4f740`) the slice was independently verifiable model
work, with no disclosure UI, YAML/TOML extraction or copy remapping. It was not
counted as delivery of the full issue.

## Complete implementation candidate — 2026-10-23

The follow-up adds parsed YAML mapping/sequence ranges with stream/scalar/comment
boundaries, and TOML table/array-of-table/array ranges with decoded key paths and
protected strings/comments. Physical YAML anchors are visited once before
materializing children. FoldProjection explicitly maps source, controls,
synthetic root headings and collapsed interiors. Copy exports complete source
for selected collapsed spans; ordinary source ellipses/object-replacement
characters are preserved. FoldingTextView uses native inline buttons only in the
viewport, exposes accessibility names/expanded state, retains child states and
supports cursor shortcuts. Raw/mode/document resets clear controls and state;
queued actions from removed buttons cannot toggle a new document's matching ID.

Fixtures and host samples now exercise nested structures in all formats. Core
and off-screen AppKit checks cover comments/scalars/streams, aliases, quoted TOML
paths/entries, logical full/partial copy, syntax restoration, state/reset/stale
actions, scrolling and 5,000-table documents within the formatting cap. The
complete final local run, including stale-action/accessibility additions, passed
54 tests, shared compilation, universal binaries and the real sandboxed launcher
round trip (`20261023T021511Z-aad9cd4a`). Log:
`artifacts/issue2-candidate-local.log`. The subsequent signed development build
passed (`artifacts/issue2-candidate-development.log`).

On-screen command-line component probes sometimes exited with status zero
without a final Swift Testing result. They are not passes. The tests now share
a serial AppKit parent and use owned off-screen windows. The command adapter
also requires an actual complete passing aggregate summary, preventing false
success from that early-exit path. Synthetic owned-view renders/expected text
are in ignored `artifacts/issue2-visuals/`; no screen capture was used.

The signed development build succeeded. Actual host/Finder UI verification is
pending because the Mac is locked; the user has been asked to unlock it. No
privacy setting was changed and the user's Full Keyboard Access preference is
left intact. Do not retry previously rejected generic Finder keyboard commands.
Open the fixture preview manually and use precise product accessibility actions
for the remaining checks. A PR must not be marked ready from component tests.

## Physical YAML boundary correction and CI evidence

Follow-up source review found that resolved block aliases could make an anchor
absorb later sibling entries. Physical indentation now bounds those entries,
including dash-only headers. Structured and alias keys retain distinct physical
ranges/headings. Visibility follows hidden interiors, preserving any structured
controls in a retained heading. Added regression coverage passes alongside the
full suite: **55 tests in nine suites**, shared compilation, universal binaries
and the real sandboxed launcher round trip. Final local report:
`.git/ai-dev-harness/runs/20261023T024048Z-a8471a57/run.json`; log:
`artifacts/issue2-physical-source-local.log`. Signed development build:
`artifacts/issue2-physical-source-development.log`.

The prior implementation commit `a752406` passed both hosted targets in
[run 39888908711](https://github.com/chomg/fileglint/actions/runs/39888908711).
Downloaded reports/logs establish all six steps, 54 tests, universal binaries,
the real sandboxed launcher regression and three actual host UI tests with zero
failures per architecture. Evidence: ignored `artifacts/issue2-ci-first/`.
This is real host-sample evidence, not actual Finder acceptance, and the YAML
correction requires its own hosted candidate evidence. Current validation status
and the final PR link belong on the authoritative issue to avoid stale claims.

## Disclosure alignment and session semantics

Owned-view visual QA found that controls before keys/markers displaced the
source indentation. Controls now follow block headings or opening delimiters;
whole block containers use a synthetic type heading with source-column padding.
Control sites are independent from range starts, and visibility/copy mapping
follow those sites. Literal source text keeps its original indentation. The
stored attributed source is immutable. Re-clicking the selected mode preserves
the current folding session; an actual mode switch or document load resets it.

Final local verification for this layout/session candidate passed all 55 tests
in nine suites, shared compilation, universal binaries and the real signed
sandboxed launcher round trip. Report:
`.git/ai-dev-harness/runs/20261023T030036Z-88a5c8b1/run.json`; logs:
`artifacts/issue2-delivery-local.log` and `artifacts/issue2-delivery-development.log`.
The development signing build also passed. Hosted evidence for the final commit
and actual Finder acceptance remain required; the locked desktop is still the
external blocker. No PR has been created before that requested validation.

## Exact TOML identities and rendered-text assertion

A failing regression proved that Swift canonical String equality could combine
distinct NFC/NFD TOML key paths, incorrectly including an unrelated child table.
Decoded paths now compare UTF-8 bytes; equivalent escaped spellings still share
the correct namespace. The complete local scope passed with all 55 tests and
native builds (`20261023T031435Z-074dbaf9`; `artifacts/issue2-exact-keys-local.log`).
The signed development build passed (`artifacts/issue2-exact-keys-development.log`).

Layout revision `6d1bff6` failed hosted UI verification on both architectures in
[run 39892991415](https://github.com/chomg/fileglint/actions/runs/39892991415).
Actual reports/logs show all earlier steps passed, and the three host UI methods
ran. The new folding/copy/reset method passed on both targets; the existing
comments method failed its displayed `[1, 2, 3]` substring assertion twice
because a disclosure is now inside the opening bracket. The assertion now checks
the visible values/comment while retaining the exact full copied-source
comparison. The final syntax/project check passed after that test-only edit
(`artifacts/issue2-exact-keys-final-check.log`). Retained failed evidence:
`artifacts/issue2-ci-layout-failed/`. A fresh hosted run must verify the final
commit; the earlier failed run is not counted as passing or silently retried.

## Next executable step

Complete the required hosted matrix for the implementation candidate. After
screen unlock, use the signed app and actual Finder previews
to verify nested folding, partial/full copying, scrolling, keyboard/Escape,
mode/document resets and unchanged bytes for every format, including `.yml`.
Record the actual Full Keyboard Access condition for Finder keyboard results.
Create the issue's single PR after acceptance; do not merge it without authority.

The normal local scope and final required hosted matrix must be recorded for
the eventual review candidate. Main/PR #5 CI does not validate this new slice.

## Finder acceptance and bounded accessibility children

After screen unlock, actual Finder Quick Look on macOS 27.0.1 arm64 exercised
JSON, YAML, `.yml` and TOML native disclosure controls, retained child states,
whole/partial logical copying, exact Raw, same-mode state retention and mode
reset. YAML stream/sibling comment boundaries and exact expansion restoration
passed. Invalid input and a valid 131,075-byte JSON document retained Raw,
diagnostics and disabled Prettified without stale folds. Long Raw copying
matched the source after correcting the diagnostic helper's pasteboard polling.
These results concern candidate `227e1f5`, not a substitute for the correction below.

The 2,000-array Finder journey revealed that TextKit exposed an additional
AXUnknown child for every attachment, alongside the viewport's native buttons.
A focused regression reproduced 2,011/2,010 accessibility children before/after
scrolling. The text view now exposes only its visible native buttons as children;
its inherited accessible text, selection and range operations remain intact.
The regression now passes, including full accessible text equality, the final
scrolled section, cursor folding and exact copying. Logs:
`artifacts/issue2-accessibility-regression-before.log` (failed as expected) and
`artifacts/issue2-accessibility-regression-after.log` (passed).

Complete the normal local scope, signed development build and both required CI
targets for this correction. Recheck Finder scrolling and all formats using the
updated signed provider, verify array-of-table entries/rapid navigation and ask
for physical keyboard/Escape acceptance. Record final results and the single PR
on the authoritative issue; previous CI passes do not validate the new revision.

The correction passed the complete local scope: 55 tests in nine suites,
shared compilation, universal binaries and the real sandboxed launcher round
trip (`20261023T045709Z-7102266e`; `artifacts/issue2-accessibility-local.log`).
The signed development build passed (`artifacts/issue2-accessibility-development.log`).

## Physical keyboard failure and scroll-content correction

Candidate `e486187` passed both hosted targets in
[run 39903203557](https://github.com/chomg/fileglint/actions/runs/39903203557).
Downloaded reports/logs establish all six steps, 55 tests, universal binaries,
the sandboxed launcher regression and three host UI tests without failures on
each architecture (`artifacts/issue2-ci-accessibility/`). Actual Finder checks
also passed all formats, logical copying, array-of-table entries, rapid
navigation, byte limits and bounded accessibility while scrolling. These passes
do not establish keyboard entry: the user could not Tab to the arrows with
Full Keyboard Access enabled, although Escape closed the preview normally.
A layout/value-notification and exterior-focus-ring prototype also failed the
user's physical retry.

The next correction moves native buttons from inside NSTextView to sibling
views in NSClipView. FoldingScrollView exposes visible buttons as independent
accessibility contents and navigation children with native scroll-area parents.
The text remains an accessible leaf with native value/selection operations;
presentation attachments are excluded. A focused regression failed three
hierarchy assertions before the correction and now passes, including actual
native hit testing, retained first responder and removal on Raw switching.
Evidence: `artifacts/issue2-scroll-peer-before.log` and
`artifacts/issue2-scroll-peer-components.log`.

The uncommitted correction passed the full local scope: **56 tests in nine
suites**, shared compilation, universal binaries and the real sandboxed
launcher regression. Report: `20261023T060812Z-3a15c206`; logs:
`artifacts/issue2-scroll-peer-local.log` and
`artifacts/issue2-scroll-peer-development.log` (signed build passed).
The refreshed actual development host exposes the text and two sample buttons
as scroll-area contents/navigation children, with correct native parents and
no nested text children (`artifacts/issue2-scroll-peer-host-hierarchy.json`).
Owned off-screen light/dark renders retain aligned visible controls; this is
component layout evidence, not a screen capture or physical keyboard evidence.

The signed provider has been refreshed and the owned YAML fixture revealed.
The user must open Quick Look manually because automatic approval review
previously rejected a generic Finder opening key. Physical Tab/Shift-Tab and
Space acceptance is pending for this structural correction. Do not count the
earlier hosted run as verification of the uncommitted correction. After that
acceptance, recheck actual Finder copying/scrolling and all formats, record the
final candidate's local and hosted evidence, and create the single PR.

### Physical acceptance and final Finder regression

The user confirmed that Tab/Shift-Tab entry and Space folding now work with
Full Keyboard Access enabled. The preference was read as enabled and left
unchanged. The earlier physical Escape result remains passing; no Escape
handler was added. Actual Finder exposes eight YAML buttons as independent
scroll contents/navigation children with native scroll-area parents
(`artifacts/issue2-scroll-peer-finder-hierarchy.json`).

The refreshed signed provider passed JSON/YAML/`.yml`/TOML nested folding,
retained child state, full/partial logical copying, exact expansion/Raw
restoration, same-mode retention and mode reset. Independent TOML table-entry
folding preserves the other entry/comments and copies complete text. Rapid
file navigation restores the final file's exact Raw with no stale folds.
Invalid input, valid 131,075-byte JSON and 1,048,577-byte input retain the
expected fallback/error and remove stale controls. Evidence:
`artifacts/issue2-scroll-peer-finder-formats.log`,
`artifacts/issue2-scroll-peer-extras.log` and
`artifacts/issue2-scroll-peer-boundaries.log`, with per-action JSON reports.

The 2,001-container Finder document passed scrolling, collapse, full logical
copy and expansion around source line 1,565; native accessibility exposed
12 controls initially and 11 after scrolling. The first diagnostic stopped
at line 935 because a single scrollbar action did not reach its required far
position. That incomplete run is retained and excluded. The corrected probe
requires an actual source line beyond 1,000 before checking fold/copy actions;
it passed (`artifacts/issue2-scroll-peer-large-complete.log`). All six owned
fixture hashes remain unchanged. Every final copy probe confirms restoration
of the saved clipboard; the earlier delayed-pasteboard probe's unconfirmed
restoration remains a recorded diagnostic limitation, not a passing result.

Complete a clean committed local verification and both hosted targets for this
final correction before PR creation. Record those final reports on issue #2.
Minimum macOS 14 and Intel Finder remain not-run release validation targets;
hosted Intel sample UI tests do not establish Intel Finder acceptance.

## Approved left-gutter revision for PR #6

The user approved a separate left gutter after reviewing the inline layout.
The updated contract is recorded on issue #2 and RFC 0004: one outermost
starting container per logical line, aligned on its first wrapped display row;
no synthetic document folds or YAML Mapping/Sequence headings; explicit root
braces/brackets remain actual containers. Expanded display text must equal the
formatted source. Raw has no gutter. Session/copy/keyboard/Escape rules remain.

FoldProjection now emits only source spans and collapsed placeholders, with
separate positions for gutter controls. Implicit YAML stream roots are omitted
while actual block entries keep their first physical line. Native buttons stay
NSClipView peers, with a non-selectable margin and reserved text inset. This
retains independent scroll accessibility contents and native parents.

New regressions failed against the inline implementation (27 assertions in two
tests; `artifacts/issue2-gutter-before.log`) and now pass. Coverage includes
exact expanded text, one left column, same-line container selection, restored
copying, omitted implicit roots, preserved YAML entry headings, first wrapped
row alignment after resizing and unchanged selection when clicking blank
gutter space. Native hit testing caught a background-layer ordering mistake;
owned visual inspection caught painting outside the margin. Both were fixed
before final verification. Synthetic light/dark renders now show source text
and aligned gutter controls without inline attachments.

The complete local scope passed **60 tests in nine suites**, shared compilation,
universal app/extension/launcher binaries and the real sandboxed launcher
regression (`20261023T092445Z-e529aeeb`; `artifacts/issue2-gutter-local.log`).
The signed development build passed (`artifacts/issue2-gutter-development.log`).
The refreshed host exposes exact formatted text and independent native buttons
with scroll-area parents (`artifacts/issue2-gutter-host-hierarchy.json`).

The owned YAML fixture has been revealed for manual opening and physical
keyboard/appearance acceptance. Actual Finder all-format/copy/scroll regression
and final-candidate hosted evidence remain pending. Do not count PR #6's earlier
inline CI or physical acceptance as validation of this redesigned candidate.
Update PR #6 after the required validation; do not merge without authority.

### Repeated Space investigation — 2026-10-26

The user refined the keyboard report: the gutter works repeatedly with roughly
one second between Space presses; rapid double presses can be missed. This was
observed in the earlier gutter build, before the following correction. It is
not evidence that the new correction fixed rapid physical activation, nor proof
of an operating-system timing rule.

A native repeated-activation check passes both before and after the correction:
six toggles per YAML section retain the same NSButton, canonical accessibility
element and first responder after layout settles. Logs:
`artifacts/issue2-gutter-repeat-before.log` and
`artifacts/issue2-gutter-repeat-atomic.log`. This is component coverage, not a
reproduction of the Full Keyboard Access input-delivery problem.

Folding now batches text replacement, source-selection remapping and viewport
restoration before updating native buttons. The final accessibility layout
notification identifies changed elements with the SDK's UI-elements payload;
intermediate renders no longer announce anonymous layouts. No keyboard hook,
artificial wait, preference change or forced-focus notification is added.

The full local scope passed **61 tests in nine suites**, shared compilation,
universal binaries and the sandboxed launcher regression
(`20261026T014528Z-db6975d9`; `artifacts/issue2-gutter-repeat-local.log`).
The signed build passed (`artifacts/issue2-gutter-repeat-development.log`).
Actual Finder passed all four extensions' nested/session/full-and-partial-copy
checks, independent TOML entries, rapid navigation and invalid/size fallbacks.
A 2,001-container document exposed 12 native controls initially and 11 after
scrolling; folding, copying and expansion passed at source line 1,025. Six YAML
buttons align in one left gutter with correct scroll-area accessibility parents,
expanded text equals Prettified, and all six fixture hashes remain unchanged.
Evidence: `artifacts/issue2-gutter-repeat-finder-formats-ready.log`,
`issue2-gutter-repeat-extras.log`, `issue2-gutter-repeat-boundaries.log`,
`issue2-gutter-repeat-large.log` and the geometry/hierarchy JSON reports.

The first diagnostic after provider refresh acted before controls were ready;
its parent driver discarded nested stderr. The retained incomplete result is
excluded. The driver now waits for actual format controls without retrying
actions and retains nested errors. The completed all-format run passed.

The corrected YAML preview is open for a physical normal/rapid Space retry.
Final committed local scope, required hosted targets and PR #6 publication
remain pending that result. Earlier inline CI is historical.

The user subsequently confirmed that the corrected build still repeats only
at a slower cadence; rapid Space presses can be missed. The physical rapid-
activation problem is therefore **not resolved** by batching notifications.
Normal physical keyboard entry and slower repeated activation work.

A task-owned, ignored `Issue2KeyboardProbe.app` now provides a plain AppKit
checkbox and a borderless native arrow button with visible action counters.
It contains no folding code, keyboard event interception or system-setting
changes. Its initial accessibility state was inspected (both counters zero),
and a physical fast-double-Space comparison is pending. Button action counts
are retained in `artifacts/issue2-native-keyboard-probe-actions.jsonl`; they
record only this diagnostic app's actions, not global keystrokes. Do not infer
an OS limitation from the uncompleted comparison. Close only this task-owned
probe after the result, then resolve or accurately bound the remaining timing
problem before finishing the PR update.

The native comparison completed: the user reported one action for slower
input and two for rapid input. The diagnostic retained 68 checkbox actions
and 52 plain-arrow actions. This does not support blaming an inherent macOS
one-second restriction.

A second isolated app links the unchanged current PreviewUI/PreviewCore and
dependency object files. Its own NSApplication subclass counts native actions
before forwarding to the real gutter button target, logging before/after
states and handler duration. No instrumentation is added to product sources
or global keyboard input. Two sessions have recorded 44 and 26 actions; every
forwarded action changed the selected section's state. Together they contain
30 consecutive same-control pairs under 25ms. In the first session handlers
took approximately 2–7ms. Evidence: `artifacts/issue2-keyboard-action-audit.json`,
`issue2-folding-probe-session-audit.json` and probe action logs. These are host
diagnostic results, not instrumentation of the actual Finder process.

A new native-control regression sends two immediate actions without sleeping,
layout passes or event-loop turns. The first collapses; the second restores
the exact expanded document, focus and complete copying. Ten pairs passed
(`artifacts/issue2-gutter-immediate-actions.log`). The full suite now contains
62 tests. The final physical clarification distinguishes two actual presses
producing two toggles from one actual press producing duplicate activations.
Do not call a return to the original state after two toggles a lost input, or
claim the physical report resolved before that clarification.

## Single-press duplication clarification — 2026-10-26

The user clarified the physical report: **one short Space press can produce two
counter increments**, rather than two deliberate presses producing two toggles.
The prior descriptions of rapid actions being missed are superseded by this
clarification. Every delivered action toggles correctly, but that does not
establish one action per physical press. This remains a material acceptance
question; do not mark rapid physical keyboard behavior resolved.

The isolated actual-module probe now also includes an unchanged plain native
checkbox. Only its own window's Space down/up metadata (no text or global input)
and button action call stacks are recorded, to distinguish native keyboard and
accessibility activation routes. The product sources and system preferences
are unchanged. Physical comparison is pending in the new diagnostic session;
log: `artifacts/issue2-real-folding-route-probe.jsonl`.

Clean committed local verification passed at `4714d40`:
`20261026T044645Z-0e0fb9b7` records clean starting/ending states and all four
steps passing, including **62 tests in nine suites**, shared compilation,
universal host/extension/launcher binaries and the real sandboxed launcher
round trip. Log: `artifacts/issue2-gutter-committed-local.log`.
Hosted checks and PR #6's gutter update remain pending the physical finding.

The window-scoped mouse-route comparison completed. The user confirmed that
rapid individual Space presses still increment by two. The diagnostic recorded
36 native checkbox actions (8 accessibility presses, 28 mouse-gesture actions)
and 44 real-module fold actions (12 accessibility presses, 32 mouse-gesture
actions). Its 120 mouse events form 60 complete down/up clicks, in 30 successive
pairs of `clickCount` 1 then 2. The fast pairs therefore arrive as double-click
sequences, with both clicks invoking the native button. Every real fold action
was forwarded and changed state once. No raw Space event reached the window.
Evidence: `artifacts/issue2-real-folding-mouse-route-probe.jsonl` and
`issue2-mouse-action-route-audit.json`. An isolated default-action-mask check
also found both native button styles use mouse-up only and are not continuous.

This bounds the observed duplication to the input path in the tested Mac
rather than an extra toggle inside the folding handler; it does not establish
an inherent restriction on every OS/version. The user has been asked whether
to retain native behavior and document the finding, or treat a double-click
sequence as one fold activation. The latter also changes actual mouse
semantics and is a consequential product choice; no arbitrary time debounce
or speculative product change has been introduced while that choice is pending.


## Accepted native activation behavior — 2026-10-26

The user selected **retain default macOS behavior** after reviewing the
window-scoped double-click evidence. The material product decision is resolved:
keep native actions without a timing filter, second-click suppression or system
preference changes. The physical quick-input report is recorded as an accepted
host-specific behavior, not a fixed OS bug or a universally reproduced limit.
Ordinary Finder keyboard entry/repeated activation and Escape passed. Both the
final clean local scope and hosted matrix must cover the publication candidate;
PR #6 must include this limit alongside the completed gutter/Finder evidence.
The task-owned diagnostic is closed after retaining its logs. No unrelated app
or Finder process is terminated.
