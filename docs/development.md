# Development Environment and Verification

Workflow: [direct](engineering/workflow.md). Platform guide: [macOS](engineering/profiles/macos.md).

## Toolchain and setup

Native Swift/AppKit + QuickLookUI; macOS 14+, arm64 and x86_64, Debug/Release. Root Swift tools manifest 6.0, Swift 5 language mode. Yams 6.2.2 and TOMLKit 0.6.0 are exact-pinned; both root and Xcode workspace Package.resolved are checked in. Python 3.10+ and uv are needed for the harness. CI pins uv 0.12.19, Python 3.12 and Xcode 26.0.1 (Swift 6.2 / macOS SDK 26.0); tool versions are logged by doctor. An explicit DEVELOPER_DIR overrides the toolchain per process, for example `DEVELOPER_DIR=/Applications/Xcode_26.0.1.app/Contents/Developer`. When the system selection is still CLT and /Applications/Xcode.app exists, the project adapter selects that full Xcode for its child processes. It preserves a different selected Xcode and never changes the global selection.

Observed bootstrap host: macOS 27.0.1 arm64, Swift 6.4 (swiftlang-6.4.0.34.1), macOS SDK 27.0, uv 0.12.19, CLT only. At initial bootstrap full Xcode and XCTest were absent; Swift Testing was available for the shared suite. The authorized follow-up installed App Store Xcode 27.1 (27A9275) at /Applications/Xcode.app; use DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer for local native validation. The user completed first launch manually. Native schemes/destinations, universal builds and Finder behavior are now verified locally; see task 0001 for actual evidence and the remaining automated UI-test limitation. A directory without `.git` supports interactive verification but cannot run committed preflight or remote CI.

```sh
uv run --script scripts/dev.py doctor
uv run --script scripts/dev.py setup
uv run --script scripts/dev.py dev
```

Setup resolves locked packages and preserves settings/data. No machine software, certificates, services or extension registration are installed automatically. Dependencies require internet on first setup; no preview needs internet. For offline harness launch, provision Python first and use `uv run --offline --no-python-downloads --script scripts/dev.py ...`.

Open Fileglint.xcodeproj and select the shared Fileglint scheme for normal native development. `dev` builds and launches the native containing app. Enable it in System Settings's Quick Look extensions panel if requested (location varies by OS). The app's instructions and Try Sample window establish rendering readiness; Finder Space-bar checks establish actual extension readiness. Quit the host with Cmd-Q; Finder owns the preview extension lifecycle.

From a checkout at any path (the folder name does not affect the build):

```sh
cd /path/to/fileglint
uv run --script scripts/dev.py verify --scope local
```

## Comment-preservation development

Try Sample now includes a format selector for JSON, YAML and TOML. Choose
YAML/TOML to inspect standalone and inline comments through the shared
Raw/Prettified view. The richer `Fixtures/comments.yaml` and
`Fixtures/comments.toml` cover streams, tags/aliases and multiline values.
The implementation and current host/check limitations are recorded in the
[issue #1 handoff](tasks/0002-comment-preservation.md); earlier bootstrap
Xcode/Finder evidence does not verify this candidate.

## Application selection development

The normal `build` check also runs `scripts/test_launcher.py`: it signs an isolated
copy of the built launcher and a minimal sandboxed client, then verifies a real
XPC round trip rejects an unregistered application. It neither registers apps
nor opens files, and needs no Finder accessibility. This catches sandbox and
signature-bootstrap failures that injected AppKit tests cannot exercise. Evidence
bundles remain under ignored `artifacts/launcher-integration-*`.

The content-header split control opens the current original file in its default
app; the separate arrow queries compatible installed apps for a one-time choice.
It is omitted in synthetic host samples. FileglintLauncher.xpc is nested inside
the preview extension; build it through the shared Fileglint scheme. Signed
bundles are required for XPC peer authentication. The unsigned universal build
verifies all three binaries but is not a runnable Finder opening acceptance test.
See [RFC 0003](rfcs/0003-open-with-applications.md) and [issue #3](https://github.com/chomg/fileglint/issues/3).

For Finder acceptance, compare the arrow menu with Finder Open With for JSON,
YAML/.yml and TOML; open the default and a different app and verify the original
document URL in each target. Check arrow-only activation launches nothing,
keyboard/Escape, both appearances, invalid Raw, navigation, and unchanged file
hashes/default associations. Failures and unavailable apps/files must be visible.

For keyboard-only access to the content-header Open controls in Finder, enable
System Settings → Accessibility → Keyboard → Full Keyboard Access. Verify
Tab/Shift-Tab navigation, Space activation and native menu arrow/Return/Escape
operation. This is separate from Keyboard Navigation under Keyboard settings.
With Full Keyboard Access off, ordinary Tab continues navigating Finder files;
mouse operation remains available. The user accepted this behavior on 2026-10-23.
Do not change the user's preference automatically or count AXPress as physical
keyboard evidence.

## Prettified folding development

`Fixtures/folding.json`, `.yaml` and `.toml` exercise nested containers, sibling
comments, literal strings, YAML streams/aliases and TOML array-of-table entries.
The host's JSON/YAML/TOML samples also use the actual disclosure implementation.
Raw has no folding controls. Switching modes/files creates an expanded session.
Copy includes hidden source when a selection crosses a fold; Select All → Copy
must equal the complete formatted text, excluding controls and synthetic labels.

Native buttons in a fixed left gutter expose section/line names and expanded
state. Expanded text equals the formatted source; no synthetic document headers
or inline attachment spaces are inserted. One arrow represents the outermost
container beginning on a logical line, on its first wrapped display row.
Implicit YAML document roots have no arrow; explicit root containers remain
foldable. The gutter is absent in Raw and excluded from text selection/copy. Finder
keyboard entry uses Full Keyboard Access; in focused text, Command-Option-Left
collapses the section at the cursor and Command-Option-Right expands it. Native
Escape handling is unchanged. For all formats, verify child-state restoration,
comment boundaries, wrapping/scrolling, partial/full copying, mode/document reset
and source bytes in the actual host and Finder, separately from component tests.

On the validated macOS 27.0.1 arm64 host, rapid individual Space presses with
Full Keyboard Access arrived as double-click sequences, producing two native
actions in both a plain macOS checkbox and the actual folding module. Two
fold actions return the section to its starting state; ordinary spaced presses
work normally. The user accepted retaining native behavior on 2026-10-26.
No timing filter or double-click suppression is applied. This observation is
specific to the tested host; it is not a claim about every macOS version.
The diagnostic evidence and physical Finder results are in the issue handoff.

The AppKit component suites share a serial parent and use owned off-screen
windows. `FILEGLINT_CAPTURE_FOLDING=1 uv run --script scripts/dev.py test` writes
synthetic view renders and expected fixture text under `artifacts/issue2-visuals/`;
it does not capture the screen or other apps. These images establish component
layout only. The test command requires a complete passing Swift Testing summary
as well as a zero exit code. See [RFC 0004](rfcs/0004-prettified-folding.md) and
the [issue #2 handoff](tasks/0004-prettified-folding.md).

## Command mappings

The product was renamed to Fileglint on 2026-10-22; see [ADR 0002](decisions/0002-product-name.md). The workspace directory was renamed from `macos-previewer` to `/path/to/fileglint` on 2026-10-22 at the user's request. Open the new path in Codex/Xcode; older chat/file links and historical logs can still refer to the original path. Swift/Xcode caches may retain absolute paths; if a moved checkout fails with stale-path errors, preserve logs, then move the generated `.build` and `artifacts/*DerivedData` directories aside and rerun setup/build. Keep historical evidence. The filesystem rename does not rename a remote repository.

The requested full rebuild after relocation passed on 2026-10-22. The old `.build` and all three derived-data directories were moved intact to `artifacts/relocation-rebuild-20261022/preserved` after checking for active checkout compilers. Fresh locked setup, all 12 tests, shared compilation, universal builds and the signed development build passed from the new path. Fresh active caches contain no old workspace text paths or symlink targets. Finder's JSON/YAML/TOML/.yml mode journeys passed against the new development binary; the malformed-file accessibility inspection timed out and the encoding/size UI cases were not repeated. See [task evidence](tasks/0001-bootstrap.md#full-rebuild-and-finder-verification-after-relocation--2026-10-22) for the exact results and limits. The user subsequently authorized removal of these archived caches. Cleanup removed the cache contents while retaining two small legacy app bundles still mapped by older diagnostic processes; all rebuild reports remain. See the cleanup entry in [task 0001](tasks/0001-bootstrap.md#cache-and-unused-scaffolding-cleanup--2026-10-22).

New native builds use `Fileglint.app` and the `Fileglint Preview` extension identity. If macOS still routes previews to Structured Preview from earlier development artifacts, disable that old provider in Quick Look extensions and enable Fileglint Preview after launching the new host. Do not change unrelated providers or default file associations.

All mappings invoke `python3 scripts/project.py <name>` from the project root; see development.json schema 2. No shell expansion in the harness mappings.

| Command | Real operation | Environment / evidence |
| --- | --- | --- |
| doctor | sw_vers, Swift/SDK/uv versions, developer authorization status, Xcode version/list/destinations | macOS + full Xcode; fails if unavailable |
| setup | swift package resolve --force-resolved-versions | SwiftPM + network/cache; checked-in lock is authoritative |
| dev | Xcode development build and open containing app | Full Xcode, graphical session; ad hoc local signing only |
| check | generator drift, plutil, Swift syntax, Python compile, lock/type-declaration agreement | macOS CLT; no source mutations |
| test | swift test --disable-xctest --enable-swift-testing | Parser + native AppKit component tests; no XCTest suite is hidden here (host XCTest UI tests are separately mapped) |
| build-shared | swift build | Shared modules, host executable and extension adapter compilation; does not package a preview extension |
| build | xcodebuild build, generic macOS, both architectures; lipo assertions on host, embedded appex and nested XPC launcher | Full Xcode; unsigned verification artifacts |
| test-ui | xcodebuild test, native platform=macOS, HostUITests | Full Xcode/XCTest, interactive desktop and UI automation authorization; artifacts/UITestDerivedData and unique xcresult |
| build-development | xcodebuild build, native current Mac, ad hoc signed | artifacts/DevelopmentDerivedData; declared sandbox entitlements, isolated from test injection |
| dev-sample | swift build --product PreviewHost and diagnostic bundle assembly | CLT fallback at artifacts/FileglintSample.app; no embedded extension or Finder registration |

No command is null/inapplicable. Missing Xcode/permissions fail the appropriate command. Shared commands explicitly use SwiftPM's native build engine for compatibility with both selected toolchains. On this CLT host the test adapter also supplies the bundled Testing framework and macro plug-in paths because SwiftPM does not discover the CLT layout correctly. Missing framework/toolchain components still fail; no test is skipped. Swift/Clang/uv caches are project-local under .build where possible. SwiftPM may use its normal host metadata cache; no credentials are logged.

## Verification scope and target matrix

| Scope | Entry point | Coverage / requirements |
| --- | --- | --- |
| Local baseline | `uv run --script scripts/dev.py verify --scope local` | check, test, build-shared, universal native build; full Xcode required to finish |
| CI candidate | `uv run --script scripts/dev.py verify --scope ci` | doctor, check, test, build-shared, universal build, native host XCUITest on each runner |
| arm64 CI | Verify / macos-arm64 on macos-15 | Xcode 26.0.1, native arm64 execution |
| Intel CI | Verify / macos-x86_64 on macos-15-intel | Xcode 26.0.1, native x86_64 execution |
| Changed behavior | parser/format/render tests and HostUITests | Normal, invalid, exact/over-limit, Unicode, streams, dates, source immutability, stale-content clearing |
| Manual platform acceptance | [Finder checklist](#finder-acceptance) | macOS 14 minimum + current macOS 27; each CPU architecture before release; actual installed/signed extension |

The CI labels and Xcode availability were checked against [GitHub's runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [Intel](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)/[arm64 image manifests](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md). Images may retire versions; update the pin deliberately, never silently use another SDK.

### Finder acceptance

On a development-signing-capable Mac, build/run the containing app from Xcode. Keep the app at a stable location; enable its Quick Look extension using System Settings if requested. Inspect `pluginkit -m -v -p com.apple.quicklook.preview` for its identity; do not reset all user preview providers.

1. Select each Fixtures/sample file in Finder and press Space. Verify this extension's Raw/Prettified controls, syntax colors, selection/copy, scrolling and Escape.
2. Switch Raw → Prettified → Raw; compare source bytes before/after. Check Unicode, YAML streams and TOML dates.
3. Select invalid.json: Raw is readable, Prettified disabled, diagnostic visible. Navigate between files and ensure no stale content.
4. Exercise a file over 1 MiB, invalid UTF-8 and a removed/unreadable path. Verify actionable errors, no hang or stale data.
5. Use native Quick Look Open, then Finder Open With another installed app. Verify original file/associations, then close only task-owned windows.
6. Repeat in light/dark appearance, check keyboard mode navigation, and record OS/architecture/build identity. Resolve conflicting preview providers explicitly instead of claiming that a generic text preview is ours.

Manual results belong in task 0001; they cannot be inferred from XCTest, `qlmanage -p`, plist validation or a build.

## CI, evidence and preflight

.github/workflows/verify.yml defines the hosted jobs. CI runs on pull requests, pushes to `main` and manual dispatch. A feature-branch push with an open PR triggers only the pull request run; branches without a PR use local verification or manual dispatch. Pushes to `main` verify the merged revision. The user authorized public GitHub source publication; the first hosted run is triggered by the initial main push. Its actual result must be checked separately from local evidence. Required branch checks after repository publication: `macos-arm64` and `macos-x86_64`. Configure them in repository settings; a workflow file does not enable protection. Both must pass at the candidate revision. CI uploads harness reports and xcresult bundles for 14 days; app bundles are verification artifacts, not releases.

Evidence: `<absolute-git-dir>/ai-dev-harness/runs/<run-id>` or ignored artifacts/harness/runs without Git. Each contains run.json and numbered logs. Logs from early interactive compiler iterations may be available only in the chat; the final aggregate records the submitted working tree checks. The user authorized local Git initialization on main and separate skeleton, requirements/design and implementation commits on 2026-10-22. Earlier non-Git reports remain under artifacts/harness; new aggregate reports use .git/ai-dev-harness. Initial history and clean committed verification are recorded in [task 0001](tasks/0001-bootstrap.md#local-git-initialization-and-three-commit-history--2026-10-22). The publication target is [chomg/fileglint](https://github.com/chomg/fileglint), with main as the selected branch. The user authorized repository creation and the initial main-only push; final remote state and first CI results are retained in the publication evidence.

Before unattended execution, intentionally commit setup, then run `uv run --script scripts/dev.py preflight --scope local` from a clean checkout. No unattended runner, commits, remote repository or publication are created by the harness. AgentCoop is not applicable.

## Change policy, resources and recovery

No new hooks or global configuration. Preserve AGENTS.md, engineering docs and existing helper contracts. Build outputs stay in .build and checkout-local artifacts: DerivedData for unsigned universal verification, DevelopmentDerivedData for signed development, and UITestDerivedData for the test runner. Xcode can inject extra file-access entitlements into UI-test builds; use the separate development app when assessing the preview sandbox. Debug builds use the current architecture, while the universal verification command explicitly builds both. Only the UI-test runner disables application hardening so it can load the ad hoc test bundle; app/extension settings are retained. No ports/databases/devices are allocated. UI tests should run serially per graphical session; other worktrees need separate derived data and must coordinate UI sessions/bundle identities. Preserve inherited COMPOSE_PROJECT_NAME even though this product uses no containers.

On failure retain code and logs; inspect run.json and its failed step before explicitly rerunning. Do not reset/clean or remove locks while their owner lives. Clean up only this task's generated resources when requested.

## Distribution and provenance

Native `build` is unsigned verification. `dev`/test-ui use ad hoc local signing, no Developer ID credentials. Production packaging, installation outside the workspace, distribution signing, notarization, uploads and store submission remain separately authorized work. No distribution channel is committed yet.

Started from AI Dev Harness 0.2.1, direct workflow. Unused scaffold metadata, the optional path checker and blank document templates were removed on 2026-10-22; the configured runner, command adapter, project generator and engineering contracts remain. Bootstrap remains partial while automated UI, hosted matrix and remaining OS/architecture acceptance evidence is missing. Native universal builds and the current arm64 Finder flows have passed locally. See [task 0001](tasks/0001-bootstrap.md) for actual results.

## Current local verification and automation authorization

On 2026-10-21, Xcode 27.1 (27A9275), Swift 6.4 and SDK 27.0 passed the full local scope. Finder Quick Look on macOS 27.0.1 arm64 displayed our extension for JSON, TOML, YAML and .yml; Raw/Prettified restoration, Unicode/dates/YAML streams, invalid JSON, invalid UTF-8, oversize errors, text selection/copy and OS app-opening flows were exercised. Source fixture hashes were unchanged. This is not hosted CI, Intel runtime or minimum-OS evidence.

HostUITests built and loaded after correcting Debug architecture alignment and test-runner hardening. It then failed to initialize UI testing: `Timed out while enabling automation mode`. No test cases ran. DevToolsSecurity reports developer mode disabled. That is a host authorization limitation to investigate, not a passing UI suite or proof of a particular root cause. The final isolated test-output path has not been rerun against the unchanged host authorization state.

An administrator can inspect `DevToolsSecurity -status` and, when explicitly approved for development use, enable the normal developer policy with `sudo /usr/sbin/DevToolsSecurity -enable`. Per its system manual, this removes the extra debugger/performance-tool password prompt for admin/_developer users. No such policy change was made here. Afterwards rerun `uv run --script scripts/dev.py test-ui` and address any remaining macOS UI-automation authorization normally; retain every result bundle. Xcode's optional External Agent Access/MCP setting is independent and is not required by these CLI commands.
