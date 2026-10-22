# Direct Workflow

The human works directly with a coding agent using this product's committed guidance. No AgentCoop installation, GitHub authentication or model-specific adapter is required by the harness.

## Contract and responsibilities

Use the active issue or docs/tasks record as the implementation contract, linked to product requirements and relevant RFC/ADR decisions. Keep one authoritative scope and acceptance list; other documents link to it. For a small change, an issue or explicit session request can be sufficient.

The human/agent agreement controls commits and publication. The harness helpers do not commit, publish, create issues, launch models or merge. Routine authorized edits and local checks proceed without repeated confirmation. Resolve meaningful product ambiguity and preserve unrelated work.

Follow the repository's [Git, pull request and review policy](../git-policy.md) for messages, history cleanup, review and merge readiness. It preserves this direct workflow and does not authorize Git or remote actions by itself.

## Work and verification

Inspect the baseline and relevant code, make a short plan when useful, and implement a small reviewable slice. Run related tests during work. Run the project's local verification scope before submission and required CI for the actual candidate revision. Use a separate session or reviewer when independent assessment adds value; deterministic checks and acceptance evidence remain necessary.

For unattended execution, first commit intentional setup/task changes and run `uv run --script scripts/dev.py preflight --scope local` in its dedicated worktree. A failed baseline starts no agent, and this helper does not provide an unattended runner. Interactive work may begin from a known dirty state only if ownership is understood; preserve it and avoid claiming baseline failures were introduced by the current task.

## Failure and handoff

Inspect the retained aggregate run report and step log, preserve code and untracked work, and fix the cause or record what external condition blocks progress. Explicitly rerun the affected scope. Do not reset/clean to recover automatically. Update the task with completed criteria, actual verification, unresolved decisions and the next executable step before handing over a long task.
