# Git, Pull Request and Review Policy

This policy applies to Fileglint's native macOS app, Quick Look extension,
tests, build scripts and documentation. It complements the
[direct workflow](engineering/workflow.md),
[agent instructions](../AGENTS.md). It grants no authority to commit,
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

## Repository stage and ownership

The user authorized initializing main and creating three local commits:
project skeleton, requirements/design, and implementation. The user also authorized publishing public `chomg/fileglint` and pushing
only main after final verification. No PR or merge is authorized. The configured Git author is retained.
The primary implementing agent owns this initial local history preparation.

This scaffold has explicitly unconfigured command mappings and no active
CI. Check documentation and configuration without claiming product tests
or builds pass. Configure the real local and hosted scopes in the
implementation commit. Hosted merge methods, reviewer requirements and
branch protection are unknown. No CODEOWNERS or release tooling exists.
Use feature/, fix/, docs/ or chore/ branch names with short lowercase
hyphenated descriptions for later scoped work.

Preserve the three meaningful initial commits. Keep caches, generated
products, personal IDE state and local evidence excluded by .gitignore.
This policy grants no additional execution authority.

## License and first publication

The user selected [MIT](../LICENSE), copyright (c) 2026 chomg, for
Fileglint's own source. Preserve upstream dependency licenses. The
publication target is public [chomg/fileglint](https://github.com/chomg/fileglint).
Only main is to be pushed. Private Codex recovery refs, old rewrite
objects, ignored caches and local reports are not publication inputs.
No binary release, notarization, store submission, PR or merge is implied.
