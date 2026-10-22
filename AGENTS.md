# Project Agent Instructions

Work within the user's authorized goal. Write project documentation in
English. Workflow: **direct**.

Read [workflow](docs/engineering/workflow.md),
[Git policy](docs/git-policy.md) and
[command meanings](docs/engineering/command-contract.md).
Preserve unrelated work and follow the current user-authorized scope.
Read [product intent](docs/product.md), [architecture](docs/architecture.md),
[planned development](docs/development.md) and the
[bootstrap contract](docs/tasks/0001-bootstrap.md) before implementation.

## Current stage

The skeleton and requirements stages contain no application implementation.
Commands in development.json are explicitly unconfigured, not passed or
inapplicable. Inspect configuration and documentation at these stages.
Add real commands, local/CI scopes, sources and meaningful checks together
with implementation. Do not create an intentionally failing test commit.

## Boundaries and recovery

The human controls commits, remote writes, history rewrites and publication.
No runner owns commits or launches models. Use only existing authorization;
production signing/distribution and destructive actions require explicit
authorization. Never weaken checks, discard unrelated changes, or remove
locks whose owners may still run. Preserve source, local app bundles and
verification evidence. Keep credentials and real user data out of code
and logs.

Report actual checks and remaining limits. A command listing proves only
configuration state; unavailable or unconfigured checks are not passes.
