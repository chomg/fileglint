# Task 0001 Configure the Product Harness

Status: Requirements and design recorded; implementation pending in this history stage

## Outcome and inputs

Implement the first usable [PRD outcome](../product.md): select a JSON,
YAML/.yml or TOML file in Finder, press Space, read syntax-colored text,
switch Raw/Prettified and use OS Open/Open With without source writes.
Follow [ADR 0001](../decisions/0001-development-environment.md),
[the naming decision](../decisions/0002-product-name.md),
[RFC 0001](../rfcs/0001-structured-preview.md),
[architecture](../architecture.md) and
[planned development](../development.md). Workflow: direct.

## Scope and acceptance

- [x] Record users, outcome, formats, constraints, exclusions and observable examples.
- [x] Select native macOS boundaries, parser dependencies and development identity.
- [ ] Add Swift modules, native app/extension/UI-test targets and both dependency locks.
- [ ] Implement bounded reads, same-format formatting, exact Raw restoration, lexical color and inline failures.
- [ ] Map real development commands and explicit local/hosted target suites.
- [ ] Add meaningful parser, control, failure and boundary checks with implementation.
- [ ] Verify native universal builds and actual Finder behavior; report target limits honestly.
- [ ] Establish hosted architecture checks when remote publication is authorized.

## Evidence and next step

This commit contains requirements/design and unconfigured scaffolding.
Product builds, parser/control tests, Finder journeys and hosted CI have
not run against this intermediate state. Do not infer success from the
command listing. Add implementation with its checks and actual evidence
in the next commit. Keep source data, local bundles and existing evidence
intact while preparing this logical initial history.
