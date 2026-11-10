# Fileglint

Preview more file formats in Finder.

A native macOS Quick Look extension for JSON, YAML and TOML. Select a supported file in Finder and press Space to read syntax-colored text, then switch between Raw and Prettified without modifying the source. A small containing app explains setup and offers a sample preview.

This extends Finder Quick Look, not Apple Preview.app. Beside Raw/Prettified, Open with the default application opens the original file; its separate arrow lists compatible installed applications for a one-time choice. Default associations are unchanged. Quick Look's native Open action and Finder's Open With remain available.

Keyboard access to the new Open controls in Finder requires macOS **Full Keyboard Access** under System Settings → Accessibility → Keyboard. With it off, ordinary Tab continues Finder file navigation; the controls remain available by mouse. Fileglint does not change this preference.

In **Prettified**, use the disclosure arrows in the left gutter to fold JSON objects/arrays, YAML mappings/sequences, or TOML tables and arrays. Child fold states survive closing/reopening a parent; changing mode or file resets them. **Copy includes hidden content** when a selection crosses a fold; Select All → Copy returns the complete formatted text and comments, excluding controls and labels. With the text focused, ⌘⌥← collapses the section at the cursor and ⌘⌥→ expands it. Finder keyboard entry uses Full Keyboard Access as described above. Raw stays unchanged.

## Personal archive and installation

Download the ZIP for your Mac and its matching `.zip.sha256` file from
[GitHub Releases](https://github.com/chomg/fileglint/releases): **arm64 for Apple
Silicon**, **x86_64 for Intel**. The ZIP is the installable app; GitHub's automatic
source-code archives are not app bundles. The original 0.1.0 Universal ZIP and
its `SHA256SUMS` remain available as historical assets; new packages are separate
architecture builds.

To build a locally signed Release ZIP yourself, install full Xcode and run:

```sh
uv run --script scripts/dev.py package-personal
```

This defaults to arm64. Build the Intel package with
`uv run --script scripts/dev.py package-personal --arch x86_64`. For each future
release, produce both packages; no new Universal package is planned.

The command creates a new directory under `artifacts/personal-archives/` with a
single-architecture ZIP, its matching `.zip.sha256` and `BUILD-INFO.json`. The ZIP
contains Fileglint.app,
installation instructions and license notices. It verifies all three binaries
and their ad-hoc signatures again after extracting the ZIP. It does not install
the app or publish a GitHub release, and needs no paid Apple developer account.

Extract the ZIP, move **Fileglint.app** to Applications, then open Fileglint once.
Enable its Quick Look extension in System Settings if requested. Keep the app's
embedded extension and XPC service together inside Fileglint.app.

**This personal build is not Developer ID-signed or notarized by Apple.** An app
downloaded through a browser may be blocked by Gatekeeper. For your own trusted,
unmodified build, first try opening it, then go to **System Settings → Privacy &
Security → Open Anyway** (Korean: **그래도 열기**) and confirm. This saves an
exception for that app. See [Apple's instructions](https://support.apple.com/en-us/102445)
and the [installation and troubleshooting guide](docs/personal-installation.md).
For a damaged bundle or invalid signature, verify the ZIP or rebuild it instead
of treating the error as an ordinary unidentified-developer warning.

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

The local gate includes the native universal app/extension/launcher build and was previously verified with Xcode 27.1; the 0.1.0 release host now has Xcode 27.2. It fails when full Xcode is unavailable. CI additionally runs host UI journeys natively on arm64 and Intel. [Finder acceptance](docs/development.md#finder-acceptance) is a separate required check. The merged feature revision passed both hosted jobs, including host UI tests, in [run 40278460966](https://github.com/chomg/fileglint/actions/runs/40278460966). Each new release candidate needs its own results. Current Mac development-build Finder flows passed; packaged Release installation, minimum-macOS and Intel Finder acceptance remain separate checks. See [bootstrap evidence](docs/tasks/0001-bootstrap.md) and the [release task](docs/tasks/0005-personal-archive.md).

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
