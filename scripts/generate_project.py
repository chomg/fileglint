#!/usr/bin/env python3
"""Deterministically emit the small native Xcode project; no third-party generator."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
objects = {}


def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def add(object_name, isa, **values):
    key = ident(object_name)
    objects[key] = {'isa': isa, **values}
    return key


def ref(path, kind, tree='<group>'):
    return add(path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree=tree)


def configs(name, settings):
    entries = []
    for mode in ['Debug', 'Release']:
        value = dict(settings)
        value['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if mode == 'Debug' else '-O'
        value['ONLY_ACTIVE_ARCH'] = 'YES' if mode == 'Debug' else 'NO'
        if mode == 'Debug':
            value['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        entries.append(add(name + mode, 'XCBuildConfiguration', name=mode, buildSettings=value))
    return add(name + 'configs', 'XCConfigurationList', buildConfigurations=entries,
               defaultConfigurationIsVisible=0, defaultConfigurationName='Debug')


package = add('localpackage', 'XCLocalSwiftPackageReference', relativePath='.')
products = []
targets = []
source_refs = []
base = {'MACOSX_DEPLOYMENT_TARGET': '14.0', 'SDKROOT': 'macosx', 'SWIFT_VERSION': '5.0',
        'CODE_SIGN_STYLE': 'Automatic', 'CODE_SIGN_IDENTITY': '-', 'DEVELOPMENT_TEAM': '',
        'ENABLE_HARDENED_RUNTIME': 'YES', 'CLANG_ENABLE_MODULES': 'YES',
        'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/../Frameworks'],
        'SUPPORTED_PLATFORMS': 'macosx'}

for name, source, product_type, suffix, plist in [
    ('Fileglint', 'Sources/PreviewHost/main.swift', 'application', 'app', 'Host'),
    ('FileglintExtension', 'Sources/PreviewExtension/PreviewController.swift', 'app-extension', 'appex', 'Extension'),
    ('HostUITests', 'UITests/HostUITests.swift', 'bundle.ui-testing', 'xctest', None),
    ('FileglintLauncher', 'Sources/PreviewLauncher/main.swift', 'xpc-service', 'xpc', 'Launcher'),
]:
    source_ref = ref(source, 'sourcecode.swift')
    source_refs.append(source_ref)
    compiled = add(name + 'source', 'PBXBuildFile', fileRef=source_ref)
    product = add(name + 'product', 'PBXFileReference', explicitFileType={
        'app': 'wrapper.application', 'appex': 'wrapper.app-extension', 'xctest': 'wrapper.cfbundle', 'xpc': 'wrapper.xpc-service'
    }[suffix], path=name + '.' + suffix, sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product)
    source_phase = add(name + 'sources', 'PBXSourcesBuildPhase', buildActionMask=2147483647,
                       files=[compiled], runOnlyForDeploymentPostprocessing=0)
    package_products = []
    linked = []
    if suffix != 'xctest':
        for library in (['PreviewOpening'] if suffix == 'xpc' else ['PreviewUI', 'PreviewCore']):
            dependency = add(name + library, 'XCSwiftPackageProductDependency', package=package, productName=library)
            package_products.append(dependency)
            linked.append(add(name + library + 'link', 'PBXBuildFile', productRef=dependency))
    frameworks = add(name + 'frameworks', 'PBXFrameworksBuildPhase', buildActionMask=2147483647,
                     files=linked, runOnlyForDeploymentPostprocessing=0)
    resources = add(name + 'resources', 'PBXResourcesBuildPhase', buildActionMask=2147483647,
                    files=[], runOnlyForDeploymentPostprocessing=0)
    settings = dict(base, PRODUCT_NAME=name, PRODUCT_BUNDLE_IDENTIFIER='dev.fileglint.' + name,
                    GENERATE_INFOPLIST_FILE='NO' if plist else 'YES')
    if plist:
        settings.update(INFOPLIST_FILE='Configuration/' + plist + '-Info.plist',
                        CODE_SIGN_ENTITLEMENTS='Configuration/' + plist + '.entitlements')
    if suffix == 'appex':
        settings.update(APPLICATION_EXTENSION_API_ONLY='YES', SKIP_INSTALL='YES',
                        PRODUCT_BUNDLE_IDENTIFIER='dev.fileglint.Fileglint.PreviewExtension')
    if suffix == 'xpc':
        settings.update(SKIP_INSTALL='YES', APPLICATION_EXTENSION_API_ONLY='YES',
                        PRODUCT_BUNDLE_IDENTIFIER='dev.fileglint.Fileglint.Launcher')
    if suffix == 'xctest':
        settings.update(TEST_TARGET_NAME='Fileglint', ENABLE_HARDENED_RUNTIME='NO')
    target = add(name, 'PBXNativeTarget', name=name, productName=name, productReference=product,
                 productType='com.apple.product-type.' + product_type,
                 buildConfigurationList=configs(name, settings), buildPhases=[source_phase, frameworks, resources],
                 buildRules=[], dependencies=[], packageProductDependencies=package_products)
    targets.append(target)

# The host embeds and depends on the extension; UI tests depend on the host.
proxy = add('extensionProxy', 'PBXContainerItemProxy', containerPortal=ident('project'), proxyType=1,
            remoteGlobalIDString=targets[1], remoteInfo='FileglintExtension')
dependency = add('extensionDependency', 'PBXTargetDependency', target=targets[1], targetProxy=proxy)
embedded = add('embeddedExtension', 'PBXBuildFile', fileRef=products[1],
               settings={'ATTRIBUTES': ['RemoveHeadersOnCopy']})
copy = add('embedExtensions', 'PBXCopyFilesBuildPhase', buildActionMask=2147483647, dstPath='', dstSubfolderSpec=13,
           files=[embedded], name='Embed App Extensions', runOnlyForDeploymentPostprocessing=0)
objects[targets[0]]['dependencies'] = [dependency]
objects[targets[0]]['buildPhases'].append(copy)
objects[targets[2]]['dependencies'] = [add('hostDependency', 'PBXTargetDependency', target=targets[0])]
# A separately sandboxed, on-demand launcher belongs to the preview extension.
launcher_proxy = add('launcherProxy', 'PBXContainerItemProxy', containerPortal=ident('project'), proxyType=1,
                     remoteGlobalIDString=targets[3], remoteInfo='FileglintLauncher')
objects[targets[1]]['dependencies'].append(add('launcherDependency', 'PBXTargetDependency', target=targets[3], targetProxy=launcher_proxy))
launcher_file = add('embeddedLauncher', 'PBXBuildFile', fileRef=products[3],
                    settings={'ATTRIBUTES': ['CodeSignOnCopy', 'RemoveHeadersOnCopy']})
objects[targets[1]]['buildPhases'].append(add('embedLauncher', 'PBXCopyFilesBuildPhase', buildActionMask=2147483647,
    dstPath='$(CONTENTS_FOLDER_PATH)/XPCServices', dstSubfolderSpec=16, files=[launcher_file],
    name='Embed File Launcher', runOnlyForDeploymentPostprocessing=0))
product_group = add('products', 'PBXGroup', children=products, name='Products', sourceTree='<group>')
main_group = add('mainGroup', 'PBXGroup', children=source_refs + [product_group], sourceTree='<group>')
project = add('project', 'PBXProject', attributes={'LastUpgradeCheck': '2600', 'TargetAttributes': {
    targets[2]: {'TestTargetID': targets[0]}}}, buildConfigurationList=configs('project', {}),
    compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0,
    knownRegions=['en', 'Base'], mainGroup=main_group, productRefGroup=product_group,
    projectDirPath='', projectRoot='', targets=targets, packageReferences=[package])


def emit(value):
    if isinstance(value, dict):
        return '{\n' + '\n'.join(f'{emit(k)} = {emit(v)};' for k, v in value.items()) + '\n}'
    if isinstance(value, list):
        return '(\n' + ''.join(emit(v) + ',\n' for v in value) + ')'
    if isinstance(value, int):
        return str(value)
    return json.dumps(value)


project_text = '// !$*UTF8*$!\n' + emit({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56,
                                           'objects': objects, 'rootObject': project}) + '\n'
entries = ''.join(f'<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[i]}" BuildableName="{name}" BlueprintName="{blueprint}" ReferencedContainer="container:Fileglint.xcodeproj"/></BuildActionEntry>'
                  for i, name, blueprint in [(0, 'Fileglint.app', 'Fileglint')])
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[0]}" BuildableName="Fileglint.app" BlueprintName="Fileglint" ReferencedContainer="container:Fileglint.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>{entries}</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[2]}" BuildableName="HostUITests.xctest" BlueprintName="HostUITests" ReferencedContainer="container:Fileglint.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
for relative, content in [('Fileglint.xcodeproj/project.pbxproj', project_text),
                          ('Fileglint.xcodeproj/xcshareddata/xcschemes/Fileglint.xcscheme', scheme)]:
    path = ROOT / relative
    if '--check' in sys.argv:
        if not path.exists() or path.read_text() != content:
            sys.exit('Generated project differs: ' + relative)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
