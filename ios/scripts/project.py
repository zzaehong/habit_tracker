"""Deterministic Xcode project generator; no external dependencies."""
import pathlib, hashlib
root=pathlib.Path(__file__).resolve().parents[1]
objects={}
def uid(s): return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def obj(key, body): objects[uid(key)]=body; return uid(key)
def configs(key, settings):
    ids=[]
    for mode in ['Debug','Release']:
        extra=' SWIFT_OPTIMIZATION_LEVEL = "-Onone"; ONLY_ACTIVE_ARCH = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if mode=='Debug' else ' SWIFT_OPTIMIZATION_LEVEL = "-O";'
        ids.append(obj(key+mode, '{isa = XCBuildConfiguration; name = '+mode+'; buildSettings = {'+settings+extra+'};}'))
    return obj(key+'configs','{isa = XCConfigurationList; buildConfigurations = ('+','.join(ids)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
pkg=obj('package','{isa = XCLocalSwiftPackageReference; relativePath = ChagokCore;}')
product=obj('library','{isa = XCSwiftPackageProductDependency; package = '+pkg+'; productName = ChagokCore;}')
targetids=[]; groupids=[]; products=[]
for name, directory, kind in [('Chagok','Chagok','application'),('ChagokUITests','ChagokUITests','bundle.ui-testing')]:
    files=[]; builds=[]
    for f in sorted((root/directory).glob('*.swift')):
        ref=obj(str(f.relative_to(root)), '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "'+f.name+'"; sourceTree = "<group>";}')
        files.append(ref); builds.append(obj('build'+name+f.name,'{isa = PBXBuildFile; fileRef = '+ref+';}'))
    if name=='Chagok':
        assets=obj('assets','{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";}'); files.append(assets)
        resbuild=obj('assetsbuild','{isa = PBXBuildFile; fileRef = '+assets+';}')
    groupids.append(obj('group'+name,'{isa = PBXGroup; children = ('+','.join(files)+'); path = '+directory+'; sourceTree = "<group>";}'))
    ext='app' if name=='Chagok' else 'xctest'; p=obj('product'+name,'{isa = PBXFileReference; explicitFileType = '+('wrapper.application' if ext=='app' else 'wrapper.cfbundle')+'; path = '+name+'.'+ext+'; sourceTree = BUILT_PRODUCTS_DIR;}'); products.append(p)
    src=obj('sources'+name,'{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+','.join(builds)+'); runOnlyForDeploymentPostprocessing = 0;}')
    frameworkfiles=[obj('libbuild','{isa = PBXBuildFile; productRef = '+product+';}')] if name=='Chagok' else []
    frameworks=obj('frameworks'+name,'{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ('+','.join(frameworkfiles)+'); runOnlyForDeploymentPostprocessing = 0;}')
    resources=obj('resources'+name,'{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ('+(resbuild if name=='Chagok' else '')+'); runOnlyForDeploymentPostprocessing = 0;}')
    settings='PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = "app.chagok.'+('ios' if name=='Chagok' else 'uitests')+'"; GENERATE_INFOPLIST_FILE = YES; SWIFT_VERSION = 6.0; IPHONEOS_DEPLOYMENT_TARGET = 18.0; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 2.0;'
    if name=='Chagok': settings+=' INFOPLIST_KEY_CFBundleDisplayName = "차곡"; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'
    else: settings+=' TEST_TARGET_NAME = Chagok;'
    conf=configs(name,settings)
    deps='';
    if name!='Chagok': deps=obj('dependency','{isa = PBXTargetDependency; target = '+uid('targetChagok')+';}')
    targetids.append(obj('target'+name,'{isa = PBXNativeTarget; buildConfigurationList = '+conf+'; buildPhases = ('+','.join([src,frameworks,resources])+'); buildRules = (); dependencies = ('+deps+'); name = '+name+'; productName = '+name+'; productReference = '+p+'; productType = "com.apple.product-type.'+kind+'"; packageProductDependencies = ('+(product if name=='Chagok' else '')+');}'))
prodgroup=obj('products','{isa = PBXGroup; name = Products; children = ('+','.join(products)+'); sourceTree = "<group>";}')
group=obj('rootgroup','{isa = PBXGroup; children = ('+','.join(groupids+[prodgroup])+'); sourceTree = "<group>";}')
conf=configs('project','SDKROOT = iphoneos; CLANG_ENABLE_MODULES = YES; ENABLE_TESTABILITY = YES; DEBUG_INFORMATION_FORMAT = dwarf;')
project=obj('project','{isa = PBXProject; attributes = {LastUpgradeCheck = 2700;}; buildConfigurationList = '+conf+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = ko; knownRegions = (ko,en,Base); mainGroup = '+group+'; productRefGroup = '+prodgroup+'; projectDirPath = ""; projectRoot = ""; targets = ('+','.join(targetids)+'); packageReferences = ('+pkg+');}')
p=root/'Chagok.xcodeproj'; p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n}; rootObject = '+project+';}\n')
s=p/'xcshareddata/xcschemes'; s.mkdir(parents=True,exist_ok=True)
def ref(name): return '<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'+uid('target'+name)+'" BuildableName="'+name+('.app' if name=='Chagok' else '.xctest')+'" BlueprintName="'+name+'" ReferencedContainer="container:Chagok.xcodeproj"/>'
(s/'Chagok.xcscheme').write_text('<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'+ref('Chagok')+'</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">'+ref('ChagokUITests')+'</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+ref('Chagok')+'</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>')
