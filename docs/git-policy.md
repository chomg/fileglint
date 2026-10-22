# Git, Pull Request and Review Policy

This policy applies to Fileglint's native macOS app, Quick Look extension,
tests, build scripts and documentation. It complements the
[direct workflow](engineering/workflow.md),
[agent instructions](../AGENTS.md) and
[development contract](development.md). It grants no authority to commit,
publish, rewrite history or merge.

## Commit messages

Describe the actual final diff in English. Use a subject **under 50
characters**, starting with a capitalized imperative verb, with no type
prefix and no final period. Conventional Commits are not selected; no
inspected release tooling requires them. Use this style consistently
across direct commits, PR commits and squash messages.

Examples:

```text
Create the Fileglint project skeleton
Document Fileglint requirements and design
Implement structured file previews
Fix raw text restoration after formatting
```

Separate an optional body from the subject with a blank line. Explain
what changes, why it changes, and relevant compatibility or data effects.
Wrap body prose at 72 characters; leave URLs and identifiers intact.
Put issue references in the body: use `Part of #123` for partial work and
`Closes #123` only when the delivered scope completes the issue. Do not
invent issue numbers when the authoritative scope is a local task.

Group one coherent change with its related tests and documentation. Do
not keep an intentionally failing test commit separate from the
implementation that makes it pass. Preserve real contributor attribution
and any required sign-offs. Do not invent attribution or append
AI-generated or co-author trailers.

## History and cleanup

Working checkpoints are acceptable during development. Before marking
direct work or a PR ready for review, consolidate temporary saves and
repeated fixes. Prefer one commit for a small, single-purpose PR. Keep
meaningful commits when they help review, debugging, revert or reuse.
There is no orchestrator-owned history cleanup stage in this direct
workflow.

Assign one history-rewrite owner for each authorized rewrite. Coordinate
before rewriting another contributor's branch. Never rewrite merged
history for cosmetic cleanup. If an authorized rewrite requires pushing,
use lease-protected force pushing. Permission to make a local commit does
not automatically authorize rewriting or pushing a shared branch.

For a squash merge, inspect the final commit subject and body. Apply the
commit style above and move issue numbers from the subject into the body.
When meaningful commits must survive, choose a preserving merge method
allowed by the host; do not squash away the agreed initial three commits.
Re-verify the resulting tree after rebase or squash, and satisfy required
CI at the resulting head.

## Pull requests

PRs are optional for solo direct work unless future branch protection or
an explicit task requires one. Use a branch and PR for substantial or
collaborative changes that benefit from a separate review record. Keep
one reviewable outcome per PR. Small direct changes still require
self-review and the applicable checks.

Use a concise English imperative title describing the final outcome,
without a type prefix. PR titles may include issue numbers and do not
inherit the commit subject's 50-character limit. Update the title and
description when scope changes. Use the existing
[PR template](../.github/pull_request_template.md).

Explain the concrete problem, resulting behavior, authoritative task or
issue, and relevant design decisions. State deviations and reasons,
undelivered requirements, material tradeoffs, compatibility/data impacts,
and remaining limitations when relevant. Report checks actually
executed, results, target/environment and evidence. Distinguish passed,
failed, blocked, not run, planned and inapplicable checks. Keep PR Markdown
naturally flowing; do not wrap PR prose at 72 characters.

## Review and merge readiness

Authors self-review the actual diff against acceptance criteria. Review
normal, failure and boundary behavior, scope, meaningful test coverage,
and relevant platform, compatibility, data, permission or security
effects. For this product, consider parser fidelity, Raw restoration,
bounded reads, extension routing, sandbox behavior and source-file
immutability when the change affects those boundaries.

Classify feedback as a **required change**, **question** or **non-blocking
suggestion**. A required finding needs a location, concrete defect or
agreed-rule violation, impact and evidence. Record how required findings
were resolved or why they do not apply. Resolve material questions before
acceptance. Re-verify behavior changes after fixes.

Before merge, confirm scope, resolved findings, history quality, required
checks and required reviews for the candidate revision. Missing tools,
unavailable targets and stale results never count as passing evidence.
AI approval does not replace tests or human acceptance.

## Repository settings and ownership

On 2026-10-22 the user authorized initializing a local repository on
`main` and creating the three initial commits below. The earlier
policy-only task prohibited Git operations; that restriction was lifted
for this initialization. The user subsequently selected the MIT license
and authorized public `chomg/fileglint` with a main-only push. PR creation
and merge remain separate actions. Hosted settings and first CI outcomes
are recorded after publication rather than inferred from local policy.

| Setting | Repository policy or observed state |
| --- | --- |
| Default branch | `main`, selected by the user for local initialization and the GitHub publication target `chomg/fileglint`. |
| Branch naming | Use `feature/<short-description>`, `fix/<short-description>`, `docs/<short-description>` or `chore/<short-description>` in lowercase with hyphens. Direct changes need no temporary branch unless separately required. |
| Merge preference | Prefer squash for a small PR; preserve meaningful multi-commit work, including the requested three-commit bootstrap, with an allowed preserving method. Hosted allowed methods are unknown. |
| Commits, pushes and PR creation | The human owns these actions and may explicitly delegate them to the agent. The user authorized the three initial commits, MIT licensing, creation of public chomg/fileglint and pushing main. PR creation and merge require their own scope. |
| History rewrites | Require authorization and a designated owner; coordinate shared branches before rewriting. No rewrite is authorized by this document. |
| Merge ownership | Human-owned unless explicitly delegated; required reviews/checks must first be established and satisfied. |
| Cleanup timing | Consolidate checkpoints before review readiness; inspect the final message again before squash merge. |
| Reviewers and code owners | No CODEOWNERS file or required reviewer assignment was found. Hosted reviewer requirements are unknown. Human acceptance remains required. |
| Branch protection | Unknown and not configured by this documentation. The development contract calls for both hosted architecture checks once published. |
| Release/changelog tooling | No automated release, changelog or commit-derived version tooling was found. Production signing, notarization, packaging and publication remain separately authorized. |

Confirm hosted merge methods, reviewer assignments, branch protection and
the remote default branch when connecting a remote. Local `main` is
already selected. Remote creation and main publication are authorized;
protection/reviewer settings must not be assumed from this document.
New authoritative organization rules or release
requirements must be reconciled explicitly before changing this policy.

## Verification and evidence

The configured commands are:

```sh
uv run --script scripts/dev.py verify --scope local
uv run --script scripts/dev.py verify --scope ci
```

The local scope runs `check`, `test`, `build-shared` and `build`: project,
syntax, plist and dependency-lock checks; Swift Testing parser/AppKit
tests; shared compilation; and the universal native app/extension build.
The CI scope adds `doctor` and native host `test-ui`.

The existing [Verify workflow](../.github/workflows/verify.yml) runs on
pushes to `main`, pull requests and manual dispatch. Feature-branch pushes
use the pull request event so each PR update creates one workflow run.
Branches without an open PR can be checked locally or by manual dispatch.
Required architecture jobs are
`macos-arm64` on `macos-15` and `macos-x86_64` on `macos-15-intel`, with
Xcode 26.0.1. Configure and confirm the host's exact check contexts when
enabling branch protection; no hosted run currently establishes them.
Both target jobs must provide real evidence at the candidate revision.
PR creation alone does not prove CI or review acceptance.

Actual Finder acceptance is separate from compilation and component
tests. Follow the [Finder checklist](development.md#finder-acceptance)
when behavior changes affect preview integration. Existing UI automation,
hosted CI and platform coverage gaps remain documented in
[task 0001](tasks/0001-bootstrap.md). Do not recast those gaps as passes.

The aggregate runner queries Git to record its state. It was not run
during the earlier policy-only task because Git operations were then
prohibited. The user has since authorized local initialization and
commits; run the normal local scope and clean committed preflight for
the implementation snapshot. Preserve the original policy-task results
as historical evidence rather than relabeling them.

Keep caches and reports in ignored `.build/` and `artifacts/`. Commit both
the root and native workspace `Package.resolved`, shared schemes,
entitlements and project-generation source. Personal Xcode state, signing
identities/profiles, local environment overrides, build products and
result bundles are excluded by [.gitignore](../.gitignore). Shared
SwiftPM configuration remains eligible for tracking. Keep private keys
outside the project or in the ignored root `local/` directory; reviewed
environment examples must contain no real credentials. Ignore rules are
selection rules, not a credential scanner or a mechanism for removing
already-tracked files.

## Initial three-commit history

The user authorized the following logical split. It organizes already
developed work; it does not claim the product was originally implemented
or verified in this order. The first two snapshots are checked as
scaffolding and documentation; the final implementation gets the normal
local gate and clean committed preflight.

| Commit subject | Intended contents | Verification at that stage |
| --- | --- | --- |
| `Create the Fileglint project skeleton` | Repository scaffolding: MIT license, ignore rules, concise README/agent guidance, Git policy, general engineering contract and generic command runner with explicitly unconfigured command mappings. No preview feature implementation or prematurely active native CI. | Documentation links and scaffold/configuration checks. Mark product builds/tests unconfigured rather than claiming they pass. |
| `Document Fileglint requirements and design` | PRD, accepted environment/name decisions, preview RFC, architecture, planned development instructions and bootstrap scope/acceptance record. | Cross-document scope and acceptance consistency. Product checks remain pending implementation. |
| `Implement structured file previews` | Swift sources, fixtures, component/UI tests, native project and shared scheme, plist/entitlements, both dependency locks, project generator/adapter, real command mappings, CI workflow, and final usage/progress documentation with actual evidence and remaining limits. | Full local scope and applicable behavior checks; required hosted/native targets must be reported with their actual status. |

These are staged project states, not three disjoint lists of today's
files. README, agent guidance, development.json and progress documents
need valid intermediate versions. Early documents must not link to files
that appear only in a later commit; the requirements-stage task records
scope, while implementation results arrive with the implementation.
Activate native command mappings and CI with the files they require.
Never create a separate failing-test commit or invent verification for
an intermediate state. Validate the final tree against the preserved
working project and keep the active development app and local reports
untouched while preparing history.

The first commit contains repository scaffolding, not a runnable empty
native application. Product sources and active native CI first appear
with the implementation. Intermediate snapshots are prepared separately
from the working source tree so the current development app, caches and
verification evidence remain intact.

## License and first publication

The user selected [MIT](../LICENSE), copyright (c) 2026 chomg, for
Fileglint's own source. Preserve upstream dependency licenses. The
publication target is public [chomg/fileglint](https://github.com/chomg/fileglint).
Only main is to be pushed. Private Codex recovery refs, old rewrite
objects, ignored caches and local reports are not publication inputs.
No binary release, notarization, store submission, PR or merge is implied.
