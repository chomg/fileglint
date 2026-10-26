#!/usr/bin/env python3
"""Product commands. No machine installation, registration or publication."""
import json
import os
from pathlib import Path
import platform
import re
import plistlib
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
os.environ.setdefault('CLANG_MODULE_CACHE_PATH', str(ROOT / '.build/clang-cache'))
os.environ.setdefault('SWIFTPM_MODULECACHE_OVERRIDE', str(ROOT / '.build/swift-cache'))
os.environ.setdefault('UV_CACHE_DIR', str(ROOT / '.build/uv-cache'))

# Prefer the installed full Xcode for this process only when the global choice
# is still CLT. Preserve an explicit override or a different selected Xcode.
if 'DEVELOPER_DIR' not in os.environ and platform.system() == 'Darwin':
    selected = subprocess.check_output(['xcode-select', '-p'], text=True).strip()
    installed = Path('/Applications/Xcode.app/Contents/Developer')
    if Path(selected).name == 'CommandLineTools' and installed.is_dir():
        os.environ['DEVELOPER_DIR'] = str(installed)


def run(*args):
    subprocess.run(args, check=True)


def swift(action, *args):
    developer = Path(os.environ.get('DEVELOPER_DIR') or subprocess.check_output(['xcode-select', '-p'], text=True).strip())
    if action == 'test' and developer.name == 'CommandLineTools':
        frameworks = developer / 'Library/Developer/Frameworks'
        plugin = developer / 'usr/lib/swift/host/plugins/testing/libTestingMacros.dylib'
        args = (*args, '-Xswiftc', '-F', '-Xswiftc', str(frameworks),
                '-Xswiftc', '-load-plugin-library', '-Xswiftc', str(plugin),
                '-Xlinker', '-F', '-Xlinker', str(frameworks),
                '-Xlinker', '-rpath', '-Xlinker', str(frameworks))
    command = ('swift', action, '--build-system', 'native', '--cache-path', '.build/cache', '--scratch-path', '.build', *args)
    if action != 'test':
        run(*command)
        return
    # Native AppKit setup can end a command-line test process with status zero
    # before Swift Testing finishes. Require its actual aggregate result too.
    complete = False
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1) as process:
        for line in process.stdout:
            print(line, end='', flush=True)
            match = re.search(r'Test run with ([1-9][0-9]*) tests? (?:in [1-9][0-9]* suites? )?passed\b', line)
            complete = complete or match is not None
        code = process.wait()
    if code:
        raise subprocess.CalledProcessError(code, command)
    if not complete:
        sys.exit('Swift Testing ended without a complete passing aggregate result; this is not a passed suite.')


def require_xcode():
    result = subprocess.run(['xcodebuild', '-version'], capture_output=True, text=True)
    if result.returncode:
        sys.exit('BLOCKED: full Xcode is required for the app/extension bundle and XCUITest. Set DEVELOPER_DIR to an installed Xcode; CLT is insufficient.')
    print(result.stdout, flush=True)


def xcode(*args, derived_data='artifacts/DerivedData'):
    require_xcode()
    run('xcodebuild', '-project', 'Fileglint.xcodeproj', '-scheme', 'Fileglint',
        '-configuration', 'Debug', '-derivedDataPath', str(ROOT / derived_data),
        '-clonedSourcePackagesDirPath', str(ROOT / '.build/xcode-packages'),
        '-onlyUsePackageVersionsFromResolvedFile', *args)


def doctor():
    if platform.system() != 'Darwin':
        sys.exit('BLOCKED: macOS is required.')
    run('sw_vers')
    run('swift', '--version')
    run('xcrun', '--show-sdk-version')
    print('Process developer directory:', os.environ.get('DEVELOPER_DIR', '(system selection)'), flush=True)
    run('DevToolsSecurity', '-status')
    run('uv', '--version')
    print('Configurations: Debug, Release; scheme: Fileglint; macOS >=14; arm64 + x86_64', flush=True)
    print('No server, ports, database, credentials or production signing needed.', flush=True)
    require_xcode()
    run('xcodebuild', '-list', '-project', 'Fileglint.xcodeproj')
    run('xcodebuild', '-showdestinations', '-scheme', 'Fileglint', '-project', 'Fileglint.xcodeproj')


def check():
    run(sys.executable, 'scripts/generate_project.py', '--check')
    paths = sorted(Path('Configuration').glob('*'))
    run('plutil', '-lint', 'Fileglint.xcodeproj/project.pbxproj', *map(str, paths))
    for path in [Path('scripts/project.py'), Path('scripts/generate_project.py'), Path('scripts/test_launcher.py')]:
        compile(path.read_text(), str(path), 'exec')
    files = sorted(Path('Sources').rglob('*.swift')) + sorted(Path('Tests').rglob('*.swift')) + sorted(Path('UITests').rglob('*.swift'))
    for path in files:
        run('swiftc', '-frontend', '-parse', str(path))
    # Validate lock and native content-type agreement, independent of project generation.
    pins = json.loads(Path('Package.resolved').read_text())['pins']
    assert {p['identity']: p['state']['version'] for p in pins} == {'yams': '6.2.2', 'tomlkit': '0.6.0'}
    host = plistlib.loads(Path('Configuration/Host-Info.plist').read_bytes())
    extension = plistlib.loads(Path('Configuration/Extension-Info.plist').read_bytes())
    imported = {v['UTTypeIdentifier'] for v in host['UTImportedTypeDeclarations']}
    assert set(extension['NSExtension']['NSExtensionAttributes']['QLSupportedContentTypes']) == imported | {'public.json'}
    assert plistlib.loads(Path('Configuration/Launcher.entitlements').read_bytes()) == {'com.apple.security.app-sandbox': True}
    assert 'CFBundleDocumentTypes' not in host  # Do not claim default handling.
    assert Path('Package.resolved').read_bytes() == Path('Fileglint.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').read_bytes()
    print('Project, Swift syntax, plist and locked-dependency checks passed.', flush=True)


def setup():
    swift('package', 'resolve', '--force-resolved-versions')
    print('Dependencies prepared. Full Xcode is needed for native bundles; run doctor.', flush=True)


def build():
    xcode('build', '-destination', 'generic/platform=macOS', 'ARCHS=arm64 x86_64', 'ONLY_ACTIVE_ARCH=NO', 'CODE_SIGNING_ALLOWED=NO')
    app = ROOT / 'artifacts/DerivedData/Build/Products/Debug/Fileglint.app'
    extension = app / 'Contents/PlugIns/FileglintExtension.appex'
    for binary in [app / 'Contents/MacOS/Fileglint', extension / 'Contents/MacOS/FileglintExtension',
                   extension / 'Contents/XPCServices/FileglintLauncher.xpc/Contents/MacOS/FileglintLauncher']:
        for architecture in ('arm64', 'x86_64'):
            run('lipo', str(binary), '-verify_arch', architecture)
    print('Universal app, embedded extension and launcher verified (unsigned).', flush=True)
    run(sys.executable, 'scripts/test_launcher.py')


def test_ui():
    result = ROOT / 'artifacts' / ('host-ui-' + uuid.uuid4().hex + '.xcresult')
    result.parent.mkdir(parents=True, exist_ok=True)
    xcode('test', '-destination', 'platform=macOS', '-resultBundlePath', str(result), 'CODE_SIGN_IDENTITY=-', 'CODE_SIGNING_ALLOWED=YES', derived_data='artifacts/UITestDerivedData')


def build_development():
    xcode('build', '-destination', 'platform=macOS', 'CODE_SIGN_IDENTITY=-', 'CODE_SIGNING_ALLOWED=YES', derived_data='artifacts/DevelopmentDerivedData')


def dev():
    build_development()
    run('open', str(ROOT / 'artifacts/DevelopmentDerivedData/Build/Products/Debug/Fileglint.app'))
    print('Open artifacts/DevelopmentDerivedData/Build/Products/Debug/Fileglint.app in Finder or Xcode. Enable the extension in System Settings if requested. Quit the app with Cmd-Q.', flush=True)


def dev_sample():
    swift('build', '--product', 'PreviewHost')
    # Assemble only a diagnostic host bundle, never advertise this as an installed extension.
    result = subprocess.check_output(['swift', 'build', '--build-system', 'native', '--cache-path', '.build/cache', '--scratch-path', '.build', '--show-bin-path'], text=True).strip()
    app = ROOT / 'artifacts/FileglintSample.app/Contents'
    (app / 'MacOS').mkdir(parents=True, exist_ok=True)
    shutil.copy2(Path(result) / 'PreviewHost', app / 'MacOS/PreviewHost')
    info = {'CFBundleIdentifier': 'dev.fileglint.SampleHost', 'CFBundleName': 'Fileglint Sample',
            'CFBundleExecutable': 'PreviewHost', 'CFBundlePackageType': 'APPL', 'NSPrincipalClass': 'NSApplication'}
    (app / 'Info.plist').write_bytes(plistlib.dumps(info))
    print('Diagnostic host ready: artifacts/FileglintSample.app (no Quick Look extension).', flush=True)


if __name__ == '__main__':
    commands = {'doctor': doctor, 'setup': setup, 'check': check, 'test': lambda: swift('test', '--disable-xctest', '--enable-swift-testing'),
                'build-shared': lambda: swift('build'), 'build': build, 'test-ui': test_ui, 'dev': dev,
                'dev-sample': dev_sample, 'build-development': build_development}
    try:
        commands[sys.argv[1]]()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
