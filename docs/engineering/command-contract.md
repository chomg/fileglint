# Development Command Contract

Share command meanings across stacks. The default entry point is `uv run --script scripts/dev.py <command>`. The helpers carry inline Python 3.10+ metadata with no third-party dependencies. From any directory, use `uv run --script "/absolute/project/scripts/dev.py" <command>`; mapped commands run from that project root. A project may select another runner if it preserves these meanings and updates its instructions and CI consistently.

## Individual commands

| Command | Required behavior |
| --- | --- |
| doctor | Inspect tool/SDK versions, required configuration names, services and target readiness without modifying the machine or printing secrets. |
| setup | Prepare dependencies and development resources repeatably; preserve existing settings and data. Separate machine installation and license acceptance. |
| dev | Start development or launch the app; document readiness, selected target and shutdown. This may be long-running. |
| check | Run finite, non-mutating formatting verification, lint/type/architecture checks appropriate to the stack. |
| test | Run the documented deterministic suite once and exit. State integration and platform coverage. |
| test-ui | Run the defined user journeys against the actual selected browser, simulator, emulator or device. Fail if the required environment is unavailable. |
| build | Produce the specified development/verification build; do not deploy, sign for distribution, notarize or upload implicitly. |

Values in development.json are null or argument arrays. Commands run from the project root with the current environment; the runner does not expand shell syntax or environment-variable references. Use a checked-in project script for several steps, host selection or working-directory changes. Command arguments and logs must not contain secrets. On Windows choose an appropriate executable or host-aware script; batch launchers may have their own command-interpreter behavior.

## Aggregate verification

`development.json` uses schema_version 2. `commands` keeps the seven common keys and may add finite checks such as test-integration or test-ios. `verification.local` and `verification.ci` are nonempty ordered lists of command names. Example structure:

```json
{
  "schema_version": 2,
  "commands": {
    "doctor": null, "setup": null, "dev": null, "check": null,
    "test": null, "test-ui": null, "build": null
  },
  "verification": {
    "local": ["check", "test", "build"],
    "ci": ["check", "test", "build", "test-ui"]
  }
}
```

The default is deliberately unconfigured. Replace null mappings with actual tools and review scope lists during bootstrap. For example, a configured test value might be `["./gradlew", "testDebugUnitTest"]` in a suitable Android project; do not assume this task exists in every build.

- `verify --scope local` runs the local list; `verify --scope ci` runs the CI list. Local is the default.
- `preflight --scope local` requires a clean Git worktree with an existing commit, runs doctor, and runs the selected verification list. Use it before an unattended run after committing the configured project.
- verify and preflight are reserved aggregate names, not remappable commands. They cannot contain setup, dev, recursive aggregates or duplicate steps. Project authors remain responsible for commands being finite and meaningful.
- Stop on the first failing or unconfigured step, preserve the exit status, and leave later steps unexecuted. No automatic retry, reset, clean, commit, agent call or publication occurs.
- A genuinely inapplicable task stays null with a reason and replacement verification in docs/development.md. Omit it from required scope lists; report it as not applicable rather than passed.
- A passing aggregate proves only that its configured checks passed. It does not establish semantic acceptance, coverage of other platforms, remote CI, or permission to merge.

AgentCoop's **Verify** workflow is a different operation: it audits completed issue delivery. It does not replace this local quality gate.

## Evidence and recovery

Aggregate runs stream tool output and retain numbered step logs and a schema-versioned run.json. The report includes the selected scope, step statuses, timestamps and observed starting/ending commit and dirty state; it does not snapshot uncommitted content or certify unchanged code. Avoid editing the same worktree during verification.

The state root is `<absolute-git-dir>/ai-dev-harness` for a Git checkout, which keeps linked-worktree evidence separate. Non-Git verification falls back to ignored artifacts/harness. Each run has a unique directory under runs/. An exclusive verification.lock prevents competing aggregate runs in the same worktree. Its owner.json records the process ID. After a crash, confirm the owner stopped and preserve evidence before removing a stale lock. Other worktrees may verify concurrently if their ports, data and devices are also isolated.

Failed or interrupted runs retain evidence. Inspect and fix the cause, keep existing work, and explicitly rerun the appropriate scope. Never erase unrelated changes. Evidence can contain tool output; keep credentials and real user data out of it and configure artifact retention/access accordingly.

## Hooks and semantic checks

Hooks are optional local feedback, not a security boundary. Do not replace an existing core.hooksPath. If integrating a hook, decide which staged check to run; tests still inspect the working tree, so CI must verify the committed candidate. Semantic rules such as Swift/Kotlin diagnostics or forbidden test skipping belong in stack-aware linters and tests, not a copied TypeScript regex policy.

## CI and platform scopes

Use the same entry points locally and in CI. Provide explicit runtime/SDK setup, locked dependencies, services, targets, artifact locations and required check names. Define a finite scope for each host; a macOS, Android or browser job cannot imply that other targets ran. Add target-specific names or project scripts when needed. Never silently drop a required platform because the current host cannot run it.

Required CI evaluates the candidate revision. Keep local test scope explicit for AgentCoop: its current precedence is issue instructions, repository instructions, then all tests. Changed/named tests remain subject to AgentCoop's own always-run requirements. Local inability may be documented and deferred to an appropriate required CI job, not labelled a pass. A green local gate does not establish remote CI results.

Applying the harness does not create product CI or remote branch rules. Build hosts, SDKs, permissions and distribution credentials remain product decisions.
