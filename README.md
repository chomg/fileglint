# Fileglint

Repository foundation for a native macOS Finder file previewer.

This stage contains project guidance and a generic command runner.
Product requirements, design and implementation follow in separate commits.
There is no application, dependency installation or active CI at this stage.

## Inspect the scaffold

Requires Python 3.10+ and uv:

```sh
uv run --script scripts/dev.py --list
```

All product commands are explicitly unconfigured. Listing them is a
configuration inspection, not a passing test or build. Configure real
commands and required local/CI scopes together with the implementation.

## Project guidance

- [Agent instructions](AGENTS.md)
- [Direct workflow](docs/engineering/workflow.md)
- [Git, pull request and review policy](docs/git-policy.md)
- [Command contract](docs/engineering/command-contract.md)

Started from AI Dev Harness 0.2.1. The command runner does not commit,
publish or launch agents. Initial history groups previously developed
work into coherent snapshots; it is not a chronological execution log.

## License

[MIT](LICENSE), copyright (c) 2026 chomg. Dependency licenses remain
applicable to their respective packages.
