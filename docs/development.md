# Planned Development Environment

Workflow: [direct](engineering/workflow.md). See the accepted
[environment decision](decisions/0001-development-environment.md) and
[bootstrap scope](tasks/0001-bootstrap.md).

## Selected platform

Native Swift/AppKit and QuickLookUI, macOS 14+, arm64 and x86_64.
Swift tools 6.0 with Swift 5 language mode. Foundation validates JSON;
Yams 6.2.2 and TOMLKit 0.6.0 provide exact-pinned YAML/TOML parsing.
Full Xcode is required for containing-app and embedded-extension builds.
Use a root Swift package for shared modules and component tests and a
native Xcode project for app/extension packaging and host UI tests.
Production distribution and signing are outside bootstrap.

## Command and verification plan

The generic runner and development.json exist, but all mappings remain
null at this history stage. Inspect them with:

```sh
uv run --script scripts/dev.py --list
```

The implementation must provide doctor, setup, dev, check, test, test-ui,
build and build-shared. Add build-development and dev-sample for isolated
ad hoc builds and the diagnostic host. Product builds/tests are not run
or claimed to pass before those sources and commands exist.

The intended local scope is check, test, build-shared and build. The
hosted scope adds doctor and native test-ui. Plan macOS 15 arm64 and Intel
jobs with Xcode 26.0.1; activate CI only with implementation. Confirm
runner readiness through actual results. No hosted evidence is claimed.

## Acceptance and isolation

The [PRD](product.md) and [RFC](rfcs/0001-structured-preview.md) define
normal, failure and boundary outcomes. Real Finder Space-bar journeys
must verify the installed extension; component tests alone cannot.
Require macOS 14/current-OS and Intel/Apple-silicon acceptance before
release. Keep current-architecture development, universal verification
and UI-test outputs separate under ignored artifacts/; caches use .build/.
Retain actual evidence and do not change unrelated providers or file
associations. Commands must not install credentials or publish implicitly.
