#!/usr/bin/env python3
"""Test real sandboxed XPC without Finder, app registration or file opening."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    subprocess.run(list(map(str, args)), cwd=ROOT, check=True, timeout=60)


def main():
    result = ROOT / 'artifacts' / ('launcher-integration-' + uuid.uuid4().hex)
    app = result / 'TrustCheck.app'
    contents = app / 'Contents'
    (contents / 'MacOS').mkdir(parents=True)
    (contents / 'Resources').mkdir()
    (contents / 'Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier': 'dev.fileglint.LauncherIntegration',
        'CFBundleExecutable': 'TrustCheck', 'CFBundlePackageType': 'APPL',
    }))
    (contents / 'Resources/source.json').write_text('{}\n')
    run('xcrun', 'swiftc', *sorted((ROOT / 'Sources/PreviewOpening').glob('*.swift')),
        ROOT / 'Tests/LauncherIntegration/main.swift', '-o', contents / 'MacOS/TrustCheck')
    source = ROOT / 'artifacts/DerivedData/Build/Products/Debug/Fileglint.app/Contents/PlugIns/FileglintExtension.appex/Contents/XPCServices/FileglintLauncher.xpc'
    helper = contents / 'XPCServices/FileglintLauncher.xpc'
    shutil.copytree(source, helper)
    # Sign only this isolated copy of the unsigned universal build. --deep also
    # signs Xcode's optional debug dylib; no installed bundle is modified.
    run('codesign', '--force', '--deep', '--sign', '-', '--entitlements',
        ROOT / 'Configuration/Launcher.entitlements', helper)
    run('codesign', '--force', '--sign', '-', '--entitlements',
        ROOT / 'Configuration/Launcher.entitlements', app)
    run('codesign', '--verify', '--deep', '--strict', app)
    run(contents / 'MacOS/TrustCheck')
    print('Launcher integration evidence:', result, flush=True)


if __name__ == '__main__':
    main()
