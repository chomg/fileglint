# Personal archive and installation handoff

The agreed task is to keep a personal installable archive of Fileglint and
document how to install it, including macOS's per-app approval if Gatekeeper
blocks a trusted ad-hoc-signed build. The user does not require paid Apple
Developer ID signing or notarization. The initial 2026-10-26 scope excluded GitHub publication. On 2026-11-10 the user
extended it to commit the packaging changes, reconcile stale documentation,
verify the candidate and publish a 0.1.0 GitHub Release with ZIP and checksum.
Installation into Applications remains outside this task.

ZIP is the selected simple container. `package-personal` creates a Universal
Release build in separate derived data, retains all bundled ad-hoc signatures,
and verifies extraction before producing the final ZIP and checksum. It includes
standalone installation instructions and provenance with the source commit and
dirty-checkout state. README links to the detailed guide and directly describes
Privacy & Security → Open Anyway for a trusted, intact personal build.

## Delivered archive and evidence — 2026-10-26

The version 0.1.0, build 1 personal archive is retained at
`artifacts/personal-archives/20261026T072510Z-3d82c9d2/Fileglint-0.1.0-build1-universal-personal.zip`.
Its directory also contains `SHA256SUMS`, `BUILD-INFO.json`, the staging folder
and the extracted round-trip copy. The ZIP includes standalone installation
instructions and Fileglint, Yams and TOMLKit license notices.

- `package-personal` passed on macOS 27.0.1 arm64 with Xcode 27.1. The actual
  Release host, extension and nested launcher each contain arm64 and x86_64,
  matching versions and valid ad-hoc signatures. Both architectures' signatures
  were checked again after extraction. File hashes, executable permissions,
  symlink targets and accompanying documents matched. The command log is
  `artifacts/personal-archive-package-final.log`.
- `shasum -a 256 -c SHA256SUMS` passed against the final ZIP.
- An isolated extracted-app copy with a modified Info.plist was rejected by
  the same signature verifier. The original ZIP and bundle were untouched;
  evidence is `artifacts/personal-archive-tamper-check.log`.
- The initial packaging run built successfully but failed before archive
  creation because this host's `lipo -verify_arch` rejected two architecture
  arguments together. The helper now checks each architecture separately,
  matching the existing build verifier. The failed log remains at
  `artifacts/personal-archive-package.log`; the explicit corrected run passed.
- The initial full local scope passed with report
  `.git/ai-dev-harness/runs/20261026T071910Z-2d3d966b/run.json`.
  Final local verification after the verifier corrections also passed:
  `.git/ai-dev-harness/runs/20261026T073824Z-7c6809ca/run.json`.
  All four steps passed, including 62 tests in 9 suites, shared compilation,
  the unsigned universal build and the real sandboxed launcher regression.

The provenance records base commit
`0692b8a5be3058e6b08c3a0b04343db9a708d82c` and `worktree_dirty: true`:
packaging and documentation changes are local and uncommitted. This is not an
artifact of a clean committed helper revision. Product Swift sources were not
changed for this task.

## Initial archive boundaries — 2026-10-26

Actual installation, Gatekeeper approval and Finder behavior of this packaged
Release app were not run. Archive integrity is not UI acceptance. Minimum-OS
and Intel Finder acceptance remain uncompleted release checks. No hosted CI
ran for these uncommitted packaging changes, and previous main/PR CI does not
validate them. No Developer ID signing, notarization, tag, GitHub release or
installation outside the workspace was performed.

The next optional step is for the owner to install this ZIP using its INSTALL.md
and exercise the host sample and Finder preview. If these helper changes are
later submitted, commit/publication need their own authorization and the actual
candidate must satisfy the repository's required hosted matrix.


## Authorized 0.1.0 publication — 2026-11-10

Acceptance for the publication candidate:

- Commit the reviewed packaging helper, installation guide and current-status
  documentation; preserve historical failures as dated evidence.
- Pass the full local scope at the committed candidate and both required hosted
  architecture jobs. Inspect their actual reports, not only job labels.
- Rebuild the Universal Release ZIP at the same clean commit and confirm its
  provenance, matching versions, both architectures, ad-hoc signatures, extracted
  file integrity and checksum. Retain the old dirty archive as historical only.
- Tag that exact commit `v0.1.0`; attach the ZIP and `SHA256SUMS` to a draft
  GitHub Release, download the assets back, verify them and then publish.
- Release notes must state personal-use ad-hoc signing, no Apple notarization,
  installation/Gatekeeper instructions and the remaining platform/UI limits.

The local release record and logs are retained under
`artifacts/release-0.1.0/`. The final candidate SHA, actual CI/local evidence,
asset names/checksum and publication outcome belong in the
[0.1.0 GitHub Release](https://github.com/chomg/fileglint/releases/tag/v0.1.0).
This avoids changing the already verified/tagged source just to record its own
commit identity. No packaging CI automation, DMG, paid signing or installation
is included.
