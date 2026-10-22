# Shared Development Principles

These agreements apply to AI-assisted development across platforms. Concrete tools, code layout, supported versions, and product decisions belong in each project.

## Describe outcomes before implementation

For a meaningful feature, record the user problem, scope, constraints, and observable acceptance criteria. Use normal, failure, and boundary examples when they affect behavior. A small issue can be sufficient; longer work should have a repository task record.

People own product intent and consequential tradeoffs. Agents may research alternatives and draft decisions. Resolve assumptions that would materially change scope or create expensive rework; choose ordinary reversible details within the authorized task.

## Deliver small usable changes

Implement a thin end-to-end slice early, then expand it. Keep changes reviewable and scoped to the goal. Use exploration to answer uncertain product questions, and capture what was learned before treating a prototype as a production harness.

## Verify with independent evidence

Use deterministic checks, behavior tests, actual application execution, and human judgment where each is appropriate. Agent self-assessment and a second agent's agreement do not replace evidence. Test important rules and regressions; do not require a new test for a cosmetic or similarly low-impact edit without a useful behavioral assertion.

Agree on expected behavior before deriving tests. Review whether tests express that behavior rather than reproducing implementation assumptions. Run related checks during work and the project's required integration checks before submission. Record failures, skipped checks, and environment limits explicitly.

## Keep knowledge with the project

Keep product intent, development commands, architecture boundaries, and important decisions in the repository. Link to the relevant documents from AGENTS.md instead of loading every document into every task. Update changed information as part of the implementation. Never depend on an old chat as the only explanation of a required behavior.

## Use reproducible environments

Record tool and SDK versions, dependency locks where supported, execution targets, and setup steps. A new worktree or CI host should follow a documented path. Setup should be repeatable and preserve existing data. A common workflow may use different hosts: Apple builds and tests require an appropriate macOS/Xcode environment.

## Match autonomy to the task

Allow routine authorized edits and local checks without repeated confirmation. Define project boundaries for deployment, real user data, signing identities, credentials, and destructive operations. Enforce access through actual credentials and execution permissions as well as instructions.

## Parallelize independent work

Start with a primary implementer. Add independent reviews, research, or well-bounded implementation tasks when they help. For simultaneous changes, isolate worktrees, ports, data, build outputs, and device allocation as needed. Assign responsibility for integration. Shared architecture and interface decisions should be coordinated before dependent work diverges.

## Improve from observed friction

Fix recurring failures in scripts, diagnostics, tests, or narrow instructions. Promote a practice to this harness when it helps multiple projects. Measure time to usable behavior, review and rework effort, escaped defects, and agent cost. Code volume alone is not a completion or productivity measure.
