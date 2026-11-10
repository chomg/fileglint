#!/usr/bin/env python3
"""Build and verify an ad-hoc-signed personal ZIP; never install or publish."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import uuid

from project import ROOT, run, xcode


def version_pair(info):
    values = (info['CFBundleShortVersionString'], info['CFBundleVersion'])
    if not all(isinstance(value, str) and re.fullmatch(r'[0-9]+(?:\.[0-9]+)*', value) for value in values):
        raise ValueError('Expected numeric app version and build number.')
    return values


def bundles(app):
    extension = app / 'Contents/PlugIns/FileglintExtension.appex'
    return (app, extension, extension / 'Contents/XPCServices/FileglintLauncher.xpc')


def verify_app(app, version):
    for bundle in bundles(app):
        info = plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
        if version_pair(info) != version:
            raise ValueError(f'Version mismatch: {bundle.name}')
        binary = bundle / 'Contents/MacOS' / info['CFBundleExecutable']
        for architecture in ('arm64', 'x86_64'):
            run('lipo', str(binary), '-verify_arch', architecture)
            signature = subprocess.check_output(
                ['codesign', '--display', '--verbose=2', '--architecture', architecture, str(bundle)],
                stderr=subprocess.STDOUT, text=True)
            if 'Signature=adhoc' not in signature:
                raise ValueError(f'Expected personal ad-hoc signature: {bundle.name} ({architecture})')
            entitlements = plistlib.loads(subprocess.check_output(
                ['codesign', '--display', '--architecture', architecture, '--entitlements', ':-', str(bundle)],
                stderr=subprocess.PIPE))
            if entitlements.get('com.apple.security.app-sandbox') is not True:
                raise ValueError(f'Expected sandbox entitlement: {bundle.name} ({architecture})')
            if entitlements.get('com.apple.security.get-task-allow'):
                raise ValueError(f'Debugger entitlement in personal archive: {bundle.name} ({architecture})')
        run('codesign', '--verify', '--all-architectures', '--strict', str(bundle))
    run('codesign', '--verify', '--all-architectures', '--deep', '--strict', str(app))


def contents_manifest(app):
    result = {}
    for path in sorted(app.rglob('*')):
        name = path.relative_to(app).as_posix()
        if path.is_symlink():
            result[name] = {'symlink': str(path.readlink())}
        elif path.is_file():
            result[name] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                            'mode': path.stat().st_mode & 0o777}
    return result


def main():
    versions = [version_pair(plistlib.loads((ROOT / f'Configuration/{name}-Info.plist').read_bytes()))
                for name in ('Host', 'Extension', 'Launcher')]
    if len(set(versions)) != 1:
        raise ValueError('Host, extension and launcher versions must match before packaging.')
    version, build = versions[0]
    # Capture provenance before building; do not imply a dirty checkout is a
    # reproducible artifact of an exact committed revision.
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all'], text=True).strip())
    xcode('build', '-destination', 'generic/platform=macOS', 'ARCHS=arm64 x86_64',
          'ONLY_ACTIVE_ARCH=NO', 'CODE_SIGN_IDENTITY=-', 'CODE_SIGNING_ALLOWED=YES',
          'CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO',
          configuration='Release', derived_data='artifacts/PersonalDerivedData')
    app = ROOT / 'artifacts/PersonalDerivedData/Build/Products/Release/Fileglint.app'
    verify_app(app, versions[0])
    manifest = contents_manifest(app)

    created = datetime.now(timezone.utc)
    output = ROOT / 'artifacts/personal-archives' / (created.strftime('%Y%m%dT%H%M%SZ-') + uuid.uuid4().hex[:8])
    stage = output / f'Fileglint-{version}-personal'
    stage.mkdir(parents=True)
    run('ditto', str(app), str(stage / 'Fileglint.app'))
    shutil.copy2(ROOT / 'docs/personal-installation.md', stage / 'INSTALL.md')
    shutil.copy2(ROOT / 'LICENSE', stage / 'LICENSE')
    licenses = stage / 'DependencyLicenses'
    licenses.mkdir()
    for package in ('Yams', 'TOMLKit'):
        shutil.copy2(ROOT / f'.build/xcode-packages/checkouts/{package}/LICENSE', licenses / f'{package}.txt')
    info = {'version': version, 'build': build, 'source_commit': commit, 'worktree_dirty': dirty,
            'created_utc': created.isoformat(), 'configuration': 'Release',
            'architectures': ['arm64', 'x86_64'], 'signing': 'ad-hoc', 'notarized': False,
            'build_host': platform.platform(),
            'xcode': subprocess.check_output(['xcodebuild', '-version'], text=True).strip(),
            'app_contents': manifest}
    (stage / 'BUILD-INFO.json').write_text(json.dumps(info, indent=2) + '\n')

    # Keep failed results for diagnosis; only give a ZIP its final name after
    # extraction, signature, architecture and content-integrity checks pass.
    pending = output / 'unverified.zip'
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(stage), str(pending))
    extracted = output / 'roundtrip'
    run('ditto', '-x', '-k', str(pending), str(extracted))
    restored = extracted / stage.name
    verify_app(restored / 'Fileglint.app', versions[0])
    if contents_manifest(restored / 'Fileglint.app') != manifest:
        raise ValueError('App contents or executable permissions changed during ZIP round trip.')
    for path in stage.rglob('*'):
        if path.is_file() and not path.is_relative_to(stage / 'Fileglint.app'):
            if (restored / path.relative_to(stage)).read_bytes() != path.read_bytes():
                raise ValueError(f'Archive document changed: {path.relative_to(stage)}')
    archive = output / f'Fileglint-{version}-build{build}-universal-personal.zip'
    pending.rename(archive)
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / 'SHA256SUMS').write_text(f'{checksum}  {archive.name}\n')
    shutil.copy2(stage / 'BUILD-INFO.json', output / 'BUILD-INFO.json')
    print(f'Personal ZIP verified: {archive}', flush=True)
    print(f'Checksum: {output / "SHA256SUMS"}', flush=True)
    print(f'Source: {commit}; dirty={dirty}; Release; universal; ad-hoc; not notarized', flush=True)


if __name__ == '__main__':
    main()
