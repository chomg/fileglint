# Architecture-specific personal archives

## Agreed scope — 2026-11-10

The user selected separate arm64 (Apple Silicon) and x86_64 (Intel) ZIPs for
future releases, with arm64 as the default packaging target. Do not produce new
Universal distribution ZIPs. Preserve the existing 0.1.0 Universal ZIP, its
SHA256SUMS, and the published v0.1.0 tag; add both single-architecture ZIPs and
their own checksum files to that release after verification. Commit/push of the
packaging/docs change and these asset uploads are authorized. No app feature,
Swift source conversion, paid signing, notarization or installation is included.

## Acceptance and implementation

- `package-personal` defaults to arm64; `--arch x86_64` selects Intel. Other
  architecture values are rejected before building. Isolate derived data per
  architecture and use explicit ARCHS rather than thinning existing signatures.
- Host, extension and nested XPC service must each contain exactly the selected
  architecture, matching versions, valid ad-hoc signatures, enabled App Sandbox
  and no debugger entitlement. Repeat checks after ZIP extraction and compare
  file hashes/permissions and bundled documents.
- Label ZIPs and extracted folders with their architecture. Emit a checksum named
  `<zip-name>.sha256` so the two assets coexist with the original SHA256SUMS.
  BUILD-INFO records exactly one architecture and the actual clean source SHA.
- Additional assets for an existing version use `--release-tag`: require a clean
  checkout and product/build-definition equivalence with the unchanged tag.
  Record both the packaging source commit and tagged product commit. Reject a
  wrong-version tag, dirty checkout or product difference before building.
- Pass clean local verification and the required hosted arm64/Intel CI at the
  committed packaging revision. Build both clean packages; verify checksums,
  wrong-architecture rejection and tampered-copy rejection using real bundles.
- Preserve existing remote asset IDs/digests and the tag. Upload the new ZIPs and
  checksums, download them back and verify bytes, provenance and signed bundles.
  Append source/evidence/download guidance to the existing release notes.

The existing unsigned universal build and both native CI targets continue as
verification; the change concerns distribution assets only. Actual installation,
Gatekeeper, minimum-OS and Intel Finder journeys remain unperformed and must not
be inferred from successful packaging or CI.

The final candidate SHA, actual check reports, asset sizes/checksums and upload
outcome are retained in `artifacts/release-0.1.0-architectures/` and the updated
[0.1.0 Release](https://github.com/chomg/fileglint/releases/tag/v0.1.0). Keeping
result metadata there avoids changing the verified commit just to name itself.

## Implementation checks before the publication candidate

Both real single-architecture builds and ZIP round trips passed on Xcode 27.2:
`package-arm64-working.log` and `package-x86_64-working.log` in the evidence
folder above. These working archives are dirty-checkout diagnostics, not upload
candidates. Invalid architecture, wrong-version tag and dirty-tag requests were
rejected before building; the original Universal app was rejected as either
single-architecture package. Evidence: `failure-checks-working.log`.
The full working local scope passed with report
`.git/ai-dev-harness/runs/20261110T081205Z-d4d2b060/run.json`. The final clean
commit, both hosted targets and downloaded release assets still require their
own evidence in the release record.
