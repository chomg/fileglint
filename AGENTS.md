# Project Agent Instructions

Work within the user's authorized goal. Default project documentation to English unless requested otherwise. Workflow: **direct**. Concrete tools and source layout belong to this product, not to a universal stack.

## Context and responsibility

- Read docs/engineering/workflow.md for the implementation contract, commit/publication ownership and recovery model. Do not substitute another workflow's rules.
- Follow [Git, pull request and review policy](docs/git-policy.md) for commit messages, history, review readiness and action ownership.
- Read docs/product.md for intent, docs/architecture.md for boundaries, and docs/development.md for actual commands, versions and selected platform guides.
- Read the active contract and related decisions/code. In AgentCoop mode the GitHub issue is authoritative; local tasks link to it instead of duplicating scope. In direct mode use the agreed task or issue.
- Shared principles and command meanings are in docs/engineering/. For an unconfigured project, start with docs/tasks/0001-bootstrap.md.

## Implement

- Inspect existing changes and preserve unrelated work. Follow the selected framework's normal layout and dependency locks.
- Make a short plan for multi-area work. Resolve consequential product/design ambiguity before expensive implementation; choose routine reversible details and continue.
- Keep changes scoped. Use RFCs for substantial proposals and ADRs for durable decisions; map acceptance examples to executable checks where useful.
- Keep each automated task independently verifiable. A failing-test/implementation cycle belongs inside a task, not in an intentionally broken queued commit.
- Routine authorized edits and local checks do not need repeated confirmation. Commit and remote-write ownership follow the selected workflow and existing session authorization.

## Verification scope

- The repository's baseline local scope is `uv run --script scripts/dev.py verify --scope local`, using verification.local in development.json. Related changed/named tests and explicit issue instructions are additional requirements; honor AgentCoop's own local-scope rules in that mode.
- Required hosted scope is `uv run --script scripts/dev.py verify --scope ci`, using verification.ci plus the target matrix documented in docs/development.md. Every required target needs real evidence at the candidate revision.
- During bootstrap, explicitly define suites and targets and any justified CI-only checks. Until then null mappings are unconfigured, not inapplicable or passed.
- A host-unavailable suite is reported as not run and assigned to required appropriate CI; never silently omit it or claim success. A local gate does not establish remote CI or semantic acceptance.
- Run useful normal, failure and boundary tests and actual UI journeys for changed user behavior. Avoid tests that merely reproduce implementation assumptions.
- Do not weaken checks or bypass hooks to finish a task.

## Execution boundaries and recovery

- The harness launches no models and owns no commits. Never add a second commit-owning runner around an AgentCoop run.
- Keep credentials, production signing material and real user data out of code, logs and reports. Actual execution authority is configured on the host; workflow documentation does not enforce permissions.
- Production deployment, store upload, production data mutation and destructive work require explicit authorization unless already authorized.
- Isolate worktrees, ports, data, build outputs and device allocation as needed. Preserve an inherited COMPOSE_PROJECT_NAME and clean up only resources owned by this task.
- On failure, inspect the retained run.json and step logs; preserve modified and untracked files. Do not reset/clean or automatically retry. Confirm a crashed lock owner stopped before removing its stale lock.

## Finish or hand off

Report changed behavior, actual target/check results and remaining limits. Update the authoritative task or issue-linked handoff with completed criteria, evidence, unresolved decisions and the next executable step. Never turn a check listing or an agent's success statement into verification evidence.
