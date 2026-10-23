# Fileglint

Preview more file formats in Finder.

A native macOS Quick Look extension for JSON, YAML and TOML. Select a supported file in Finder and press Space to read syntax-colored text, then switch between Raw and Prettified without modifying the source. A small containing app explains setup and offers a sample preview.

This extends Finder Quick Look, not Apple Preview.app. Beside Raw/Prettified, Open with the default application opens the original file; its separate arrow lists compatible installed applications for a one-time choice. Default associations are unchanged. Quick Look's native Open action and Finder's Open With remain available.

Keyboard access to the new Open controls in Finder requires macOS **Full Keyboard Access** under System Settings → Accessibility → Keyboard. With it off, ordinary Tab continues Finder file navigation; the controls remain available by mouse. Fileglint does not change this preference.

## Develop

Requires macOS 14+, Swift 6.0+ and full Xcode for native app/extension builds. Dependency versions are locked. Read [development setup and verification](docs/development.md) for exact toolchains and supported targets.

```sh
uv run --script scripts/dev.py doctor
uv run --script scripts/dev.py setup
uv run --script scripts/dev.py dev
```

Open Fileglint.xcodeproj and choose the shared Fileglint scheme for Xcode debugging. The project discovers /Applications/Xcode.app when the global developer selection is still CLT; an explicit DEVELOPER_DIR takes precedence. Builds and caches stay inside this checkout. No production signing or installation is performed by setup. Signed development builds use artifacts/DevelopmentDerivedData, independently of test and universal-verification outputs.

For CLT-only component development:

```sh
uv run --script scripts/dev.py test
uv run --script scripts/dev.py build-shared
uv run --script scripts/dev.py dev-sample
```

The resulting artifacts/FileglintSample.app is a diagnostic host only; it does not contain or register the Quick Look extension.

## Verify

```sh
uv run --script scripts/dev.py verify --scope local
uv run --script scripts/dev.py verify --scope ci
```

The local gate includes the native universal app/extension/launcher build and passes on the installed Xcode 27.1. It fails when full Xcode is unavailable. CI additionally runs host UI journeys natively on arm64 and Intel. [Finder acceptance](docs/development.md#finder-acceptance) is a separate required check. Actual results and remaining limitations are in [task 0001](docs/tasks/0001-bootstrap.md); the current Mac Finder flows pass, while automated UI authorization and the remaining platform/hosted checks are still pending.

Files are UTF-8, up to 1 MiB. Prettification is capped at 128 KiB input, bounded complexity and 4 MiB output; larger supported text stays in Raw. YAML/TOML prettification preserves comments and source layout while normalizing spacing. Invalid content retains Raw with an error.

## Project knowledge

- [PRD](docs/product.md)
- [Stack decision](docs/decisions/0001-development-environment.md)
- [Product name and identifiers](docs/decisions/0002-product-name.md)
- [Preview design RFC](docs/rfcs/0001-structured-preview.md)
- [Architecture](docs/architecture.md)
- [Git, pull request and review policy](docs/git-policy.md)
- [Agent instructions](AGENTS.md) and [direct workflow](docs/engineering/workflow.md)

Started from AI Dev Harness 0.2.1. The retained command runner does not commit, create remote repositories, publish or launch agents.

## License

[MIT](LICENSE), copyright (c) 2026 chomg. Dependency licenses remain
applicable to their respective packages.
