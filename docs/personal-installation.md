# Personal archive installation

This archive contains an ad-hoc-signed Release build for the owner's personal
use. It is not signed with an Apple Developer ID certificate and is not
notarized by Apple. No paid developer account is needed to build it locally.
The app targets macOS 14 or later. Choose **arm64 for Apple Silicon** or
**x86_64 for Intel**; each new ZIP contains only its named architecture.
Minimum-OS and Intel Finder acceptance remain separate uncompleted release
checks; building an architecture does not establish its runtime results.
The original 0.1.0 Universal archive contains both architectures and remains
available, but new releases provide separate arm64 and x86_64 packages.

## Install or update

1. If replacing a previous copy, quit Fileglint and close its Quick Look preview.
2. Extract the ZIP. Inside the `Fileglint-<version>-<architecture>-personal` folder, move
   **Fileglint.app** to your Applications folder. Keep its bundled components
   intact; do not install the `.appex` or `.xpc` separately.
3. Open Fileglint once. If macOS asks, enable Fileglint's Quick Look extension
   in System Settings. The exact Extensions settings location varies by macOS.
4. Try the host app's sample, then select a JSON, YAML/YML or TOML file in Finder
   and press Space. Raw/Prettified and folding appear in this extension's preview.

Keep one intended installed copy. Development and installed copies use the same
bundle identities and may compete as Quick Look providers. An ordinary text
preview without Fileglint's controls does not prove that this extension ran.

For keyboard entry into preview buttons, enable System Settings → Accessibility
→ Keyboard → Full Keyboard Access if desired. This remains a user preference.
Rapid Space activation follows native macOS click behavior, including the
double-click sequences observed on the validated macOS 27 host.

## If macOS blocks the first launch

A browser-downloaded archive can cause Gatekeeper warnings even if you built
the app yourself. A locally built app does not necessarily show the same warning.
If this is your own trusted build and its integrity is intact:

1. Attempt to open the installed Fileglint.app once.
2. Open **System Settings → Privacy & Security**, then scroll to Security.
3. Click **Open Anyway** (Korean: **그래도 열기**) for Fileglint.
4. Confirm **Open** and authenticate if macOS requests it.

macOS saves an exception for that app. Availability can depend on device
management policy. Follow [Apple's current instructions](https://support.apple.com/en-us/102445).
Keep Gatekeeper enabled; this is an app-specific approval, not a global change.

## Verify a damaged archive or signature error

Download the `.zip.sha256` file matching your ZIP. From the directory containing
both files, run, for example:

```sh
shasum -a 256 -c Fileglint-0.1.0-build1-arm64-personal.zip.sha256
```

For Intel use the matching `x86_64` checksum filename instead. Only the original
0.1.0 Universal ZIP uses `shasum -a 256 -c SHA256SUMS`. Its extracted folder is
`Fileglint-0.1.0-personal` without an architecture suffix.

The checksum detects changes to the archive; it is not proof of Apple approval.
Check the installed bundle's signatures with:

```sh
codesign --verify --deep --strict "/Applications/Fileglint.app"
```

If the checksum or signature fails, restore your original archive or rebuild.
An Open Anyway exception does not repair a modified or incomplete app bundle.
Retain the ad-hoc signatures: Fileglint's extension and XPC launcher authenticate
each other using their bundled peers' signatures.

## Archive records

`BUILD-INFO.json` records the version/build, source commit, dirty-checkout flag,
toolchain, architecture and hashes/permissions of the bundled app files. A dirty
flag means the source revision alone does not describe every working-tree change.
For an exact committed source record, build from a clean committed checkout.
Additional packages for an existing release also record `release_tag` and
`release_product_commit`: product sources/build definitions must match that
unchanged tag, while `source_commit` identifies the updated packaging revision.

The packaging command uses separate Release build output and a fresh archive
directory each time. It copies with macOS `ditto`, extracts the resulting ZIP,
and verifies signatures, sandbox entitlements without debugger access, the exact
selected architecture in all three binaries, version consistency, file hashes,
executable permissions and accompanying documents. Incomplete ZIPs retain the
name `unverified.zip`; only a successful check produces the final archive name.
