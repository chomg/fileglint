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

## Next executable step

Complete the required hosted matrix for the implementation candidate. After
screen unlock, use the signed app and actual Finder previews
to verify nested folding, partial/full copying, scrolling, keyboard/Escape,
mode/document resets and unchanged bytes for every format, including `.yml`.
Record the actual Full Keyboard Access condition for Finder keyboard results.
Create the issue's single PR after acceptance; do not merge it without authority.

The normal local scope and final required hosted matrix must be recorded for
the eventual review candidate. Main/PR #5 CI does not validate this new slice.
