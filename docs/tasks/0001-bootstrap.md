# Task 0001 Configure the Product Harness

Status: Partially complete — local gate and current Mac Finder flows pass; automated UI authorization and remaining target/hosted evidence pending

## Outcome and inputs

A developer can prepare the product environment, inspect the shared native sample UI and execute honest verification. Workflow: **direct**. This file is the authoritative bootstrap contract. See [PRD](../product.md), [ADR 0001](../decisions/0001-development-environment.md), [RFC 0001](../rfcs/0001-structured-preview.md), [architecture](../architecture.md) and [development](../development.md).

The user agreed on 2026-10-21 to a Quick Look extension with a minimal containing app. The intended usable product is Finder Space → colored structured text → Raw/Prettified → open the original in an editor. The implementation is usable through Finder on the current arm64 Mac; the follow-up below records actual native/Finder evidence and remaining limits.

## Scope and acceptance

- [x] Define primary users, first usable outcome, platforms and exclusions in product.md.
- [x] Resolve the native Swift/AppKit + QuickLookUI stack, one repository and explicit host constraints in ADR 0001.
- [x] Create native Xcode app/extension/UI-test targets and normal Swift package source/test layout; exact-pin parsers and commit-ready resolution files. No existing files were overwritten outside the bootstrap documentation/configuration scope.
- [x] Implement doctor, repeatable locked setup and all finite command mappings in development.json schema 2. Missing platform tools correctly fail readiness/build checks.
- [x] Define explicit local/CI lists and actual target matrix. No unavailable target is labelled passed or inapplicable.
- [x] Implement bounded read-only raw/prettified JSON/YAML/TOML, lexical colors, native text selection and inline error/fallback behavior, with an RFC and meaningful shared checks.
- [ ] Complete native universal app/extension build, XCUITest and installed Finder acceptance on required targets. The full local gate, universal build and current arm64 Finder checks pass. Automated UI initialization and the remaining OS/architecture checks are pending.
- [ ] Establish hosted verification evidence and required branch checks. The real two-host workflow and local Git history are configured; no remote or hosted CI run exists here.
- [x] Document path policy, worktree/build/UI-session isolation, evidence/recovery and release boundaries. Existing engineering guidance/helpers and hooks were preserved.
- [x] Finish committed/bootstrap preflight. Local main has the three requested commits; clean committed local preflight passed. The result-only documentation amendment is rechecked at its final head, with evidence below. No publication is authorized.
- [x] AgentCoop criterion is not applicable: selected workflow is direct; no agent runner or managed issue flow was introduced.

## Implementation and resolved decisions

- Native app/extension: Fileglint.xcodeproj with shared scheme, generated deterministically by scripts/generate_project.py (called StructuredPreview.xcodeproj in the original evidence below). SwiftPM builds the same shared modules and a diagnostic host; that host does not contain/register a Quick Look extension.
- Foundation validates JSON; whitespace-only formatting retains numeric lexemes, duplicate keys and escapes. Yams 6.2.2 handles YAML nodes/streams; TOMLKit 0.6.0 handles TOML tables/dates. Formatting is same-format and in memory. Raw preserves decoded UTF-8, BOM and line endings. YAML/TOML pretty output can remove comments or normalize layout.
- Source reads cap at 1 MiB, formatting at 128 KiB input with bounded nesting/indentation and 4 MiB output. Complexity/parser errors keep Raw and disable Prettified. Invalid UTF-8, missing files and oversize reads show errors and clear stale UI content.
- macOS 14+, Apple silicon and Intel. App Sandbox enabled for host/extension. Production signing/notarization/distribution remain outside bootstrap.
- Native Quick Look Open and Finder Open With are the initial external-app flow. Custom in-extension app picking is deferred until sandbox behavior is proven; no default associations are changed.

## Verification evidence — 2026-10-21

All results below are from an uncommitted directory with no Git metadata, on macOS 27.0.1 arm64, Swift 6.4 (swiftlang-6.4.0.34.1), SDK 27.0, uv 0.12.19. They are not candidate-revision hosted evidence.

| Criterion | Command or flow | Actual result and evidence |
| --- | --- | --- |
| Setup | `uv run --script scripts/dev.py setup` | Passed: locked dependencies resolved. No machine installation. |
| Local gate | `uv run --script scripts/dev.py verify --scope local` | Overall failed at required native build because full Xcode is absent. Retained report: artifacts/harness/runs/20261021T082433Z-96c4a2c1/run.json. Failed step inspected; no reset/clean or retry of unavailable build. |
| Source/config check | Local gate, check (01.log) | Passed: deterministic project/scheme drift, Swift syntax, Python compile, plist validity, lock versions/consistency and declared content-type agreement. This does not establish Xcode project semantics or Finder routing. |
| A2–A5/A7 component behavior | Local gate, test (02.log) | Passed: 12 Swift Testing tests across PreviewDocumentTests and PreviewViewTests. Covers JSON semantics/scalars/BOM/large numeric lexemes/escapes/duplicate keys; YAML streams/scalars/aliases and late stream errors; TOML tables/arrays/dates/Unicode; invalid formats/encoding/paths; byte and complexity boundaries; unchanged source bytes; token ranges; actual AppKit action dispatch, colored attributes, Raw restoration, disabled invalid formatting and stale-content clearing in both appearances. |
| Shared compilation | Local gate, build-shared (03.log) | Passed: PreviewCore, PreviewUI, PreviewHost and PreviewExtension adapter compile on arm64. Does not package or load an appex. |
| Native universal bundle | Local gate, build (04.log) | Not run: readiness check exits 1 because xcodebuild requires full Xcode. No universal app/appex, signature or Intel evidence. |
| CI-scope readiness on current host | `uv run --script scripts/dev.py verify --scope ci` | Failed at doctor for absent full Xcode. Report: artifacts/harness/runs/20261021T082612Z-ae09d474/run.json; failed step inspected. Later CI steps were not run. This was a local invocation, not hosted CI. |
| Native app UI journey | `uv run --script scripts/dev.py test-ui` | Not run: exits 1 on missing full Xcode/XCTest. Required on both CI hosts. |
| Diagnostic app actual UI | `dev-sample`, background launch via cua-driver | Host built/launched. Setup instructions, Try Sample window, colored JSON Raw view visually inspected on the real app in dark appearance. Screenshots: artifacts/manual/setup-dark.png and raw-dark.png. The first AX click reported failure but the sample window appeared; the next mode-switch attempt failed and its window identity/Space changed. Interactive Prettified/Raw/copy/keyboard journey is not claimed verified; component actions passed separately. |
| A1/A6 installed Finder flow | Space / Escape, modes, default/other apps | Not run: no built/installed extension. Required manual matrix in development.md. A generic system preview is not evidence for this extension. |
| Hosted matrix | Verify / macos-arm64 and macos-x86_64 | Not run: .github/workflows/verify.yml configured for macos-15/macos-15-intel, Xcode 26.0.1; no authorized Git remote/candidate revision. Branch protections are not configured. |
| Preflight | clean committed checkout | Not run: no .git or commit. No unattended execution was launched. |

The test suite exposed and fixed real defects: Foundation UTF-8 decoding dropped a BOM from Raw; a lazy YAML stream iterator swallowed malformed-document errors; and AppKit's inherited changeMode selector collided with our mode action. Regression cases remain in the suite. Swift 6.4's new default build engine did not supply Testing macro paths during module emission, so shared commands explicitly use SwiftPM's native engine. The CLT layout also needs its bundled Testing framework/plugin paths. These are documented toolchain adaptations, not skipped tests; missing components still fail.

## Follow-up: installed Xcode and native/Finder verification

The user authorized full Xcode installation on 2026-10-21 and completed first launch manually. App Store Xcode 27.1 (27A9275) is installed at /Applications/Xcode.app, with Swift 6.4 and macOS SDK 27.0. No mobile simulator downloads were requested, no credentials were collected, and the global developer directory remains /Library/Developer/CommandLineTools. Project commands select the installed full Xcode for their processes when the global choice is still CLT, while preserving explicit DEVELOPER_DIR or another selected Xcode.

Xcode's optional External Agent Access was discussed: these CLI commands do not require its MCP service. No external-agent access setting or developer authorization policy was changed by the agent. The user was advised to choose Never for the current workflow; While Xcode is Open is an optional future MCP integration choice.

### Native corrections

- Honor process-local DEVELOPER_DIR when locating test frameworks and discover the installed standard Xcode when appropriate.
- Use a proper containing-app prefix for the extension ID: dev.structuredpreview.StructuredPreview.PreviewExtension.
- Align Debug targets with the native architecture; explicitly override to both architectures in universal verification. Release builds retain both by default.
- Verify each architecture separately with lipo: this host's multi-architecture -verify_arch invocation errored even though the binaries were fat. Both individual assertions succeed.
- Retain application hardening settings for the app/extension, not the ad hoc XCTest runner that loads a test bundle. Xcode reports hardened runtime disabled for these ad hoc development signatures; production runtime/signing is not claimed verified.
- Isolate unsigned universal, signed development and UI-test derived data. The signed Finder build's actual entitlements contain only app-sandbox and get-task-allow; the broader temporary read exceptions injected into test builds were not used for Finder acceptance.

### Actual evidence

All results are from the uncommitted working directory on macOS 27.0.1 arm64, with Xcode 27.1. No Git candidate revision or hosted run exists.

| Check / criterion | Actual result | Evidence |
| --- | --- | --- |
| Xcode readiness | Passed: native project targets, schemes, package graph and arm64/Any Mac destinations inspected | `uv run --script scripts/dev.py doctor` with process-local full Xcode; artifacts/native-verification/doctor.log |
| Final baseline local scope | Passed: check, 12 Swift Testing tests, shared build, universal app + embedded extension build; lipo independently verifies arm64 and x86_64 for both | artifacts/harness/runs/20261021T111320Z-f1e7fd7a/run.json and 01–04.log; artifacts/native-verification/final-local-gate.log |
| Signed development bundle | Passed: build-development, deep/strict signature validation, declared sandbox permissions inspected | artifacts/native-verification/development-build.log; artifacts/DevelopmentDerivedData/Build/Products/Debug/StructuredPreview.app |
| Native host sample | Passed manually: Try Sample, colored Raw text, Prettified expansion and exact Raw restoration | Actual development host AX observations in chat |
| A1/A2/A4 Finder normal flows | Passed on current Mac: Space selected this extension for sample.json, sample.toml, sample.yaml and generated alias.yml. Raw/Prettified/Raw works for JSON/TOML/YAML; Unicode, TOML dates and YAML stream separator are displayed correctly. Escape closes Quick Look. | Actual Finder AX observations and JSON screenshot in chat; generated fixture in artifacts/native-verification/Fixtures |
| A3 invalid content | Passed: invalid.json remains readable with a visible error and disabled Prettified | Actual Finder preview AX state in chat |
| A5 size/encoding errors | Passed: 1,048,577-byte JSON reports the 1 MiB limit; invalid UTF-8 YAML reports encoding guidance. Both modes disabled, content empty, no previous document text retained. | Generated synthetic fixtures and Finder AX observations in chat |
| Selection/copy | Passed manually: selected YAML text visibly highlighted in Quick Look; Cmd-C clipboard bytes exactly matched Fixtures/sample.yaml (comparison printed only True) | Screenshot and clipboard match output in chat; no user clipboard contents were logged |
| A6 OS opening flows | Passed: Quick Look Open with Antigravity IDE opened the original sample.json path. Finder one-time Open With → TextEdit opened the same original path and expected JSON. Always Open With was not used. | Actual target-app AX states in chat |
| Source immutability | Passed: all four committed fixture SHA-256 checks matched after formatting and opening in both apps | artifacts/native-verification/fixtures-before.sha256; `shasum -a 256 -c` output |
| XCTest attempt 1 | Failed to build: Debug extension attempted x86_64 linking against arm64-only package objects; corrected target architecture alignment | artifacts/native-verification/host-ui.log; host-ui-e77a7ede86934203a40fd40faf527950.xcresult |
| XCTest attempt 2 | Failed to load test bundle because the test runner inherited application hardening; corrected runner-only setting | artifacts/native-verification/host-ui-attempt2.log; host-ui-f78466a02f21476cbd706b38933980e4.xcresult |
| XCTest attempt 3 | Failed before executing tests: runner loaded, then timed out enabling UI automation mode. DevToolsSecurity reports developer mode disabled. No authorization policy was changed and the suite is not marked passed. | artifacts/native-verification/host-ui-attempt3.log; host-ui-749e1bc257c043808c1a9e7b21bd581d.xcresult |
| Hosted/other targets | Not run: native Intel runtime, minimum macOS 14, other current-OS architecture journeys and the hosted CI matrix still need their own evidence | Required matrix in development.md |

The final command now isolates UI-test derived data; it has not been rerun against the unchanged host automation authorization state. The last UI runtime failure and result bundle are retained. The final local gate passed after all source/configuration corrections. Test-only registration was replaced with the task's declared-entitlement development extension for Finder checks; only this project's registrations were touched. Final registration and development entitlements are retained in artifacts/native-verification/extension-registration.txt and development-extension-entitlements.plist; the source-integrity check is in fixtures-after.log. The task-created Finder fixture tab was closed after verification.

### Remaining work and next executable step

1. An administrator should review the Mac's developer-tool/UI automation authorization. The XCTest runner failed enabling automation, and developer mode is disabled; this observation does not establish a unique root cause. If approved for development use, `sudo /usr/sbin/DevToolsSecurity -enable` enables Apple's normal debugger/performance-tool policy for admin/_developer users. This is separate from optional External Agent Access. Then rerun `uv run --script scripts/dev.py test-ui`, handle any remaining normal macOS automation authorization, and retain its result. Do not weaken the application sandbox to make it pass.
2. Run the required hosted arm64/Intel jobs at a real candidate revision and complete the minimum/current OS manual matrix. Current-host success is not evidence for those targets. Global appearance changes and unreadable/missing-file Finder races were not manually exercised; component failure/appearance tests passed separately.
3. Establish Git/commit ownership, commit intentional bootstrap work, run clean preflight and publish only when authorized. No remote repository, commit or production distribution was created by this task.

## Follow-up: Fileglint rename — 2026-10-22

The user chose **Fileglint**, repository name **fileglint**, and authorized applying it. [ADR 0002](../decisions/0002-product-name.md) records the naming and development identifiers. The PRD, README, architecture/development/stack docs, native project/scheme/targets, app and extension bundle identities/display names, host UI, diagnostic host, error domain, sample fixtures and UI-test expectations now use Fileglint. Shared module names, the initial structured-preview RFC URL, dependency versions/locks, and historical evidence are preserved. At the time of this product rename, the folder was still `macos-previewer`; the subsequent folder relocation is recorded below. No `.git` or remote existed to rename.

| Check | Actual result and evidence |
| --- | --- |
| Initial sandboxed local gate | Configuration checks passed; SwiftPM failed at its normal compiler sandbox with `sandbox_apply: Operation not permitted`. This is a tool execution boundary, not a manifest source error. Inspected and retained artifacts/harness/runs/20261022T015534Z-ff49b880/run.json and 02.log. No sandbox was disabled in the app or build configuration. |
| Normal local gate outside tool sandbox | Passed: check, all 12 Swift Testing tests, shared build, and unsigned universal Fileglint.app + FileglintExtension.appex with independent arm64/x86_64 assertions. artifacts/harness/runs/20261022T015602Z-cd836f41/run.json; artifacts/fileglint-rename/local-gate.log. |
| Development app and identities | Passed: ad hoc build-development, deep/strict signature validation, expected display names/bundle IDs and containing-app prefix. artifacts/fileglint-rename/development-build.log and bundle-identities.json. |
| Renamed Xcode UI-test target | `xcodebuild ... build-for-testing -project Fileglint.xcodeproj -scheme Fileglint` passed. artifacts/fileglint-rename/ui-test-build.log. This compiles the renamed UI-test expectations; it does not execute them. The previous automation-mode initialization failure remains unresolved; full XCUITest was not rerun. |
| Real host UI | Passed: background launch reports Fileglint, setup screenshot shows Fileglint branding/instructions, Try Sample opens colored JSON containing Fileglint, and Prettified expands it. artifacts/fileglint-rename/setup.png, sample-raw-state.json, sample-prettified-state.json and matching screenshots. CuaDriver reported an AX error on Try Sample despite opening the window; the resulting window/content were inspected rather than treating the action status as success. |
| Current Mac Finder routing | Passed after refresh: initial preview was generic system text. Removed only this project's unsigned/test app registrations, retained the declared-entitlement development extension, refreshed Quick Look with `qlmanage -r`, and reopened the synthetic JSON. Its own preview-mode/status/content identifiers appear; Prettified expands Fileglint JSON and Raw restores the original fixture text. artifacts/fileglint-rename/finder-preview-raw.json, finder-preview-prettified.json and finder-preview-restored.json. Earlier failed background selection actions were inspected; the observed context-menu Quick Look action and subsequent Space reopening loaded the preview asynchronously. |
| Local extension identity migration | Only this project's old identity was elected ignore and the new Fileglint identity elected use. The final registered Fileglint provider is the DevelopmentDerivedData bundle; the test bundle was unregistered. artifacts/fileglint-rename/old-registration-final.txt and new-registration-final.txt. No unrelated providers, default file associations, developer security policies or production signing settings changed. |
| Documentation and source review | Relative Markdown links resolve; generated project drift check passes; dependency lock bytes remain unchanged. Old branding remains only in historical evidence/migration explanation. Pre-change snapshot and review diff: artifacts/fileglint-rename/before and changes.diff. Sample fixture branding changed intentionally; earlier SHA-256 values apply to earlier fixture versions. Current hashes: artifacts/fileglint-rename/fixtures-after.sha256. |

The new identity's Finder check covers JSON on this Mac; the original broader format/error/open-with checks above describe the old identity. Hosted CI, minimum macOS/Intel runtime acceptance and automated XCUITest still need their own evidence. The remaining executable steps above continue to apply. The workspace was subsequently relocated to `fileglint`, as recorded below. Create a remote named fileglint only when publication is authorized.

## Follow-up: workspace folder relocation — 2026-10-22

The user explicitly requested moving `/path/to/macos-previewer` to `/path/to/fileglint` and reopening it in Codex. This is a directory rename, with no Git/remote change. Source hashes are captured before and compared after the move; existing generated caches, logs and build outputs are preserved. Verification and Codex reopening status are recorded in `artifacts/workspace-relocation/`. Earlier absolute evidence paths and older chat links describe the original location.

Next development commands remain `uv run --script scripts/dev.py check` and `uv run --script scripts/dev.py verify --scope local` from the new directory. Relocation can invalidate absolute paths in Swift/Xcode caches; preserve any failure logs and move only generated caches aside if a new build reports stale paths. Full hosted CI and automated UI authorization remain outstanding as recorded above.

### Confirmed Codex move and remaining-path audit — 2026-10-22

The user moved this chat into the new fileglint project. The shell's actual working directory and Codex's recorded chat cwd both equal `/path/to/fileglint`. The old directory is absent and is not a compatibility symlink.

A hidden/ignored-file text scan found no old workspace path in active source, scripts, package/native project configuration, CI or fixtures. Four documentation references described migration/history; stale present-tense folder guidance was clarified. Before recording this audit, 1,356 generated/history text files contained the old absolute path, chiefly Swift/Xcode caches and old evidence. One generated compiler-cache lock symlink also targets the old directory. These were preserved; no lock was deleted and no cache was reset. Swift/native build execution after relocation has not been established by this audit.

The active Fileglint Quick Look registration did still reference the old development app path. Re-registering the existing declared-entitlement development bundle at the new path replaced that record: pluginkit now reports one enabled Fileglint provider under the new workspace. Explicit removal at the absent old path reported no plugin; no unrelated provider was modified. This establishes the registered path, not a new Finder UI journey. Before/after records and audit details are in `artifacts/workspace-relocation/`. The configuration/source check is rerun from the new cwd; a full build, Finder journey, automated UI suite and hosted CI were not rerun for this path audit.

## Full rebuild and Finder verification after relocation — 2026-10-22

The user explicitly requested a full rebuild from `/path/to/fileglint`, stale-cache recovery and actual Finder Quick Look verification. No product code, package requirements, source fixtures, entitlements or build mappings needed changes.

### Cache recovery and rebuild

The tool sandbox initially disallowed process enumeration; the authorized host-side check found no running compiler/build process for this checkout. The old `.build` and `artifacts/DerivedData`, `DevelopmentDerivedData`, and `UITestDerivedData` directories were moved intact into `artifacts/relocation-rebuild-20261022/preserved`. This also preserves the old orphaned absolute compiler-lock symlink; no individual lock was removed. Original logs, modified/untracked files and dependency locks were retained. The rebuild started with fresh active Swift and native build caches rather than editing generated files in place.

| Operation / criterion | Actual result and evidence |
| --- | --- |
| Locked dependency setup | Passed: Yams 6.2.2 and TOMLKit 0.6.0 fetched/resolved into fresh caches. `artifacts/relocation-rebuild-20261022/setup.log`. |
| Full local gate | Passed: check, 12 Swift Testing tests, build-shared, and universal app/embedded-extension build. Both arm64 and x86_64 asserted separately. `artifacts/harness/runs/20261022T022731Z-a4b051d0/run.json` and numbered logs; `artifacts/relocation-rebuild-20261022/local-gate.log`. No Git candidate revision exists. |
| Signed development bundle | Passed from a fresh DevelopmentDerivedData directory. Deep/strict codesign verification succeeds. Actual extension entitlements contain only app-sandbox and get-task-allow, without temporary exceptions. `development-build.log` and `development-extension-entitlements.plist` in the rebuild evidence directory. Production signing/hardening is not established by ad hoc signing. |
| Fresh-cache path audit | Zero old absolute workspace text references in `.build`, unsigned DerivedData and signed DevelopmentDerivedData; zero old-target symlinks in fresh `.build`. `fresh-cache-audit.json`. Old references remain intentionally in preserved caches/history. |
| Product source integrity | All 47 pre-build source/config/document hashes matched after setup and builds, before this evidence documentation update. Package locks remained unchanged. `sources-before.json`. All 11 original/synthetic fixture hashes still match after UI actions: `fixtures-before.json` and `fixtures-after.json`. |

### Actual Finder journeys on the current arm64 Mac

The fresh unsigned verification app was unregistered and the declared-entitlement signed development extension registered at its stable new workspace path. Pluginkit reports one enabled Fileglint provider there (`extension-registration.txt`). `lsof` confirms a running FileglintExtension has that exact new development executable open (`extension-runtime-binary.txt`), rather than an archived executable. Finder was driven through native cua-driver actions with snapshots before/after dispatch, using only synthetic fixtures under the rebuild evidence directory.

| Journey | Actual result and evidence under artifacts/relocation-rebuild-20261022 |
| --- | --- |
| JSON Quick Look | Passed: Finder context-menu Quick Look loads this extension's preview-mode/status/content identifiers and exact Raw fixture text. Prettified expands JSON; Raw restores the exact original bytes. `json-open-result.json`, `json-prettified-result.json`, `json-restored-result.json` and corresponding AX snapshots. |
| Space reopening | Passed: close the synthetic JSON panel, press Space on the selected fixture, and observe this extension with exact Raw content; close again. `json-space-result.json` and close results. |
| YAML and TOML | Passed: actual Finder Raw → Prettified → Raw for each format, including YAML stream/Unicode content and TOML dates. Raw equals the corresponding source exactly. `sample.yaml-*-result.json`, `sample.toml-*-result.json` and AX snapshots. |
| .yml alias | Passed: same native mode journey and exact Raw restoration for the synthetic alias of the YAML fixture. `alias-*-result.json` and snapshots. |
| Malformed JSON | Not verified in the rebuilt extension's UI: context-menu dispatch succeeded, but the following get_window_state request timed out after 40 seconds. A diagnostic inspection after switching to AX-only capture also timed out. Both failures are retained in `invalid-json-open-stderr.log` and `invalid-json-observed-stderr.log`; no UI success is inferred. Component/parser malformed-input checks passed in the local gate. |
| Invalid UTF-8 and oversized files | Synthetic fixtures and hashes prepared, but these UI journeys were not run after the malformed-file inspection failures. Their automated boundary/encoding checks passed in the local gate; earlier UI evidence remains dated to earlier builds. |

The native helper remained responsive to status/config queries. Original capture_mode=som was restored in a finally block (`capture-ax.log` and `capture-som.log`). Escape was delivered to dismiss the task's malformed-file panel, but the subsequent Finder observation also timed out after 20 seconds, so dismissal/window cleanup is not claimed verified. No further Finder actions were dispatched after that. Some AXShowMenu calls reported an error even when the menu appeared; successful journeys were assessed from the observed menu, preview content and mode transitions, not action return codes alone. `finder-actions.jsonl` and the evidence-only `finder_probe.py` retain the sequence. Screenshots captured through the owning Finder window show the fixture window; preview assertions above are from the Quick Look panel's accessibility tree, not a claim that those screenshots show the floating panel or newly prove color/appearance behavior.

### Outcome and remaining limits

The requested fresh local rebuild and normal Finder preview journeys pass from the renamed workspace. Active stale build caches have been replaced while retaining all previous caches and logs. Overall results are in `artifacts/relocation-rebuild-20261022/verification-summary.json`. No host security policy, unrelated preview provider, default file association, production signature, commit or remote was changed.

Follow up on the malformed-file native inspection timeout before claiming the rebuilt extension's error UI or full manual checklist complete. Automated XCUITest execution was not rerun; the earlier automation-mode initialization limitation remains unresolved. Hosted CI, native Intel runtime and minimum/current-OS manual matrix targets still require their own evidence. These limits do not change the passing full local gate or the observed normal Finder flows.

## Cache and unused scaffolding cleanup — 2026-10-22

The user authorized removing archived caches and unused harness files while preserving working commands, verification reports and the active Quick Look extension. Removed the unused `.harness.json` provenance manifest, unwired `scripts/check_changes.py`, three blank `docs/templates/` files and root Finder metadata. Updated live documentation references. Retained the configured runner, product adapter, project generator, development.json, engineering guidance, CI, dependency locks, existing decisions/RFCs/tasks, current caches and native app bundles.

Removed 3,088,108 KiB (about 2.95 GiB) of allocated archived cache contents under `artifacts/relocation-rebuild-20261022/preserved`. No compiler was using the archive. Older diagnostic processes still map the archived `DerivedData/.../Fileglint.app` and `DevelopmentDerivedData/.../StructuredPreview.app`, so those two complete bundles remain at their existing paths (17,304 KiB total). No process was terminated. The active Fileglint extension maps the current signed development bundle outside the archive. Actual APFS free-space recovery may differ from allocated-size reduction while mappings or snapshots persist.

| Check | Actual result and evidence |
| --- | --- |
| Required local gate | Passed: configuration/syntax checks, all 12 Swift Testing parser/AppKit tests, shared build, universal app and embedded extension with both architecture assertions. `artifacts/harness/runs/20261022T031304Z-b22aad96/run.json` and numbered logs; `artifacts/cleanup-20261022/local-gate.log`. |
| Preserved files | All 3,990 existing evidence files, 27 working source/config/build files and 11 files in the active signed app bundle match their pre-cleanup hashes or symlink targets. `integrity-before.json` and `integrity-after.json` in the cleanup evidence directory. |
| Active Quick Look | Deep/strict signature verification passed. Pluginkit still reports the same single enabled Fileglint provider UUID at `artifacts/DevelopmentDerivedData/Build/Products/Debug/Fileglint.app/Contents/PlugIns/FileglintExtension.appex`. The running extension still maps that executable. `extension-before.txt`, `extension-after-build.txt`, `runtime-before.txt`, `runtime-after.txt` and `codesign-verify.log`. |
| Command/document integrity | All command mappings remain configured; relative Markdown links resolve. No live instructions invoke the removed optional helper or templates. `command-mappings.txt` and `integrity-after.json`. The runner's harness report metadata and evidence directories remain intentionally intact. |

The cleanup inventory and measured sizes are recorded in `artifacts/cleanup-20261022/removal.json`. Previous preservation entries above describe history; only the two in-use legacy bundles remain in that archive now. A later cleanup can remove them after their diagnostic processes exit. Finder GUI journeys and XCUITest were not repeated for this cleanup; no product behavior changed. Existing malformed-file inspection, UI automation, hosted CI, Intel runtime and OS matrix limitations remain. The next product verification step is to resolve the recorded UI automation authorization limitation and run `uv run --script scripts/dev.py test-ui`, retaining its result bundle; hosted matrix checks require a published candidate.

## Git policy and initial history planning — 2026-10-22

The user supplied commit/PR/review instructions and requested documentation, an ignore-rule audit and a plan for three initial commits, explicitly prohibiting Git operations. Added [Git policy](../git-policy.md), linked it from README, AGENTS and the direct workflow, and extended the existing PR template. Commit subjects use capitalized imperative English, fewer than 50 characters, no type prefix and no final period. Body prose wraps at 72 characters; issue references belong in the body. The earlier chat suggestion of Conventional Commits was never selected and is superseded by this explicit policy.

The policy records action ownership, history cleanup, review/merge readiness, actual verification commands and architecture jobs, unknown hosted settings and the requested skeleton → requirements/design → implementation plan. Intermediate README, instructions, mappings and progress records must describe their actual stage rather than prematurely promise a working preview. No source or intermediate commit state was prepared by this documentation task. The proposed initial default branch is main; actual remote branch/merge/reviewer/protection settings remain unconfirmed.

Expanded `.gitignore` for default native build output, app/extension/debug/archive/result bundles, local overrides/signing profiles and editor temporary files. Narrowed the broad `.swiftpm/` exclusion to personal/generated state so shared SwiftPM configuration can be tracked. Dependency locks, shared schemes, entitlements and synthetic fixtures remain eligible. Existing caches, signed development app and verification evidence were preserved.

Validation passed using ripgrep's explicit ignore-file matcher, without invoking Git: 33 synthetic generated/local paths excluded, 27 shared/source/example paths retained, and zero generated-path leaks in the actual 43-file eligible inventory. Relative Markdown links, commit subject examples and command/CI policy consistency passed. All 38 protected source/configuration/command/active-app hashes matched. Evidence: `artifacts/git-policy-20261022/protected-files-before.json` and `validation.json`.

The baseline aggregate was not run for this task because its state recording invokes Git, contrary to the user's restriction. No Git commands, initialization, staging, commits, history/remote queries, pushes, PRs or merges were performed. No build, Finder journey, UI suite or hosted job was rerun for these documentation/ignore changes. Once authorized, prepare and verify the three coherent intermediate states, initialize the repository and create their commits; that future work must preserve the working final tree and local evidence.

## Local Git initialization and three-commit history — 2026-10-22

The user authorized local initialization on main and exactly three logical
commits: project skeleton, requirements/design, and implementation. Remote
creation and pushing remain excluded. The existing configured author is
used without changing global Git settings or inventing attribution.

The skeleton contains 11 scaffolding files, a generic command runner and
seven explicitly null product mappings. The requirements snapshot adds
the PRD, decisions, architecture, RFC and planned bootstrap/development
contracts (18 files total). Both snapshots pass relative-document-link,
Python-syntax and command-list checks; no product tests/builds are claimed
at those stages. Native sources, locked dependencies, mapped commands,
tests, CI and actual implementation evidence arrive together in the third
commit. Intermediate README, agent guidance and task records match each
stage. Snapshots are prepared separately under ignored artifacts without
replacing working source files or the signed development app.

Subjects: `Create the Fileglint project skeleton`,
`Document Fileglint requirements and design`, and
`Implement structured file previews`. The first two commits are
63f09bc and bf4e387. Final implementation verification must run against
its clean committed head. Earlier source/build/Finder results remain
historical and do not imply hosted CI or new UI acceptance.

Evidence lives in `artifacts/git-bootstrap-20261022/`: original inventory
and source/app hashes, both staged snapshots, intermediate validation,
commit message files and clean-checkout verification logs. The aggregate
runner now records new reports in `.git/ai-dev-harness/runs`; all prior
`artifacts/harness` reports remain preserved. Final preflight and integrity
results are recorded below after execution. No remote, push, PR or merge
is created by this task.

### Local history verification results

| Check | Actual result and evidence |
| --- | --- |
| Intermediate commits | Skeleton 63f09bc (11 files) and requirements bf4e387 (18 files) passed stage-specific links, Python syntax and unconfigured-command inspection. `intermediate-validation.json` and stage command-list logs. Product tests/builds were not available at these stages. |
| Clean committed local preflight | Passed on initial implementation candidate 37da206: doctor, check, all 12 Swift Testing parser/AppKit tests, shared build, and universal app/extension build with both architecture assertions. Starting and ending Git states were clean at that revision. `.git/ai-dev-harness/runs/20261022T043929Z-d6124555/run.json`; `initial-clean-preflight.log`. |
| Native signing and routing integrity | Existing development app passes deep/strict signature verification; all 11 app/extension bundle hashes match the pre-Git baseline. Same single enabled Fileglint extension UUID and current DevelopmentDerivedData path remain registered. `codesign-verification.log` and `extension-registration.txt`. No new Finder UI journey is claimed. |
| Working tree and previous evidence | All 43 intended project files are selected, with no generated products/reports staged. Only four documentation files differ from the original final project; all 50 remaining source/config/command/app hashes and all 4,008 previous evidence files match. `candidate-validation.json` and `integrity-after.json`. |
| Real Git ignore rules | Passed: 12 local/generated paths excluded and eight shared/source/example paths retained. The initial probe used .build/debug, a symlink; Git rejected that path. A corrected direct-child probe passed without changing ignore rules. `git-inspection.json` and `git-ignore-probe-initial.txt`. |
| Branch and publication boundary | Local branch main, three commits, no configured remotes. No push, PR or merge was performed. The existing author identity was retained. |

This result-only documentation update is folded into the third commit so
history retains exactly the requested three commits. Run clean preflight
again at the resulting head. Its exact revision, checks, final status and
integrity are retained in `artifacts/git-bootstrap-20261022/summary.json`
and `final-clean-preflight.log`, avoiding a self-referential commit hash
in the tracked task record. The original preflight above remains evidence
for its explicitly named revision.

Hosted CI was not run because no remote or push was authorized. Automated
XCUITest, remaining Finder error/OS/architecture acceptance and production
distribution limitations remain unchanged. The next product verification
step is still to resolve UI automation readiness and run the mapped
native test-ui command; remote setup and hosted checks require separate
authorization.

## Workspace metadata anonymization — 2026-10-22

The user authorized rewriting the three local commits to anonymize personal
workspace paths and remove the Codex project identifier. Documentation now
uses generic /path/to/ checkout examples. The repository-scaffolding,
requirements/design and implementation boundaries, commit messages, author
names and author emails remain intact. Source code, dependency locks,
build commands, the signed development app and existing local evidence
are preserved. No remote, push, PR or merge is authorized.

Earlier bootstrap reports and revision references above describe the
original local history. Those ignored reports remain available locally;
they are not claims of verification at the rewritten head. The rewritten
history's privacy scan, identity/tree comparisons and clean committed
local verification are recorded in
`artifacts/history-anonymization-20261022/summary.json` and associated logs.
The primary implementing agent owns this explicitly authorized local
rewrite. No backup branch or tag exposes the superseded history through
ordinary branch/tag publication. Git's local recovery objects and ignored
historical reports may retain the original metadata; this task does not
purge those local recovery resources.

## MIT license and public GitHub publication — 2026-10-22

The user selected MIT with copyright (c) 2026 chomg and authorized creating
public `chomg/fileglint` and pushing main. The license and README link are
incorporated into the skeleton and retained through requirements/design
and implementation, preserving exactly three commits. Existing author
and committer names/emails, dates and messages are preserved. Product
code, dependency locks, build commands and the signed development app
are unchanged. Current hosting authorization supersedes earlier
local-only restrictions; no PR, merge or binary release is requested.

Before publication, validate all three snapshots, scan the exact main
history for secrets and personal workspace/Codex metadata, and run the
clean committed local preflight. Push only main with no automatic tags;
do not mirror private refs or local recovery snapshots. Check the public
visibility, default branch, remote commit chain, MIT detection and first
hosted CI results. Do not claim pending or failed hosted checks passed.

The publication evidence, exact rewritten commit identities, local
verification, remote state and initial CI observations are recorded in
`artifacts/github-publication-20261022/summary.json` and associated logs.
Earlier local reports retain their original revision references and are
not relabeled as evidence for the published head. Hosted branch
protection/reviewer requirements must be observed explicitly; a workflow
file alone does not configure them. Existing UI automation and remaining
Finder/OS/architecture acceptance gaps remain until actual target results
establish otherwise. Binary signing, notarization and release packaging
remain separate work.
