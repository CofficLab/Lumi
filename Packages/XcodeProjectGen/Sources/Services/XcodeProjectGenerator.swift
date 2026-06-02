import Foundation
import XcodeProj
import PathKit

/// 核心生成器：根据 `XcodeProjectSpec` 生成完整的 `.xcodeproj` 项目。
///
/// 使用方式：
/// ```swift
/// let generator = XcodeProjectGenerator()
/// let spec = XcodeProjectSpec(name: "MyApp", targets: [...])
/// try generator.generate(spec: spec, projectRoot: "/path/to/project/root")
/// ```
public final class XcodeProjectGenerator: Sendable {

    /// 生成选项。
    public struct Options: Sendable {
        /// 是否生成 Shared Schemes。
        public let generateSchemes: Bool
        /// 是否使用确定性 UUID（便于测试和 diff）。
        public let deterministicUUIDs: Bool
        /// XcodeProj 写出时是否格式化输出。
        public let formattedOutput: Bool

        public init(
            generateSchemes: Bool = true,
            deterministicUUIDs: Bool = false,
            formattedOutput: Bool = true
        ) {
            self.generateSchemes = generateSchemes
            self.deterministicUUIDs = deterministicUUIDs
            self.formattedOutput = formattedOutput
        }
    }

    private let options: Options

    public init(options: Options = Options()) {
        self.options = options
    }

    // MARK: - Public API

    /// 根据 Spec 生成 Xcode 项目。
    ///
    /// - Parameters:
    ///   - spec: 项目配置声明。
    ///   - projectRoot: 项目根目录的绝对路径。
    /// - Returns: 生成的 `.xcodeproj` 目录路径。
    @discardableResult
    public func generate(
        spec: XcodeProjectSpec,
        projectRoot: String
    ) throws -> String {
        let rootPath = Path(projectRoot)
        guard rootPath.exists else {
            throw XcodeProjectGenError.projectRootNotFound(projectRoot)
        }

        // 1. 验证 Spec
        try validate(spec: spec)

        // 2. 构建 PBXProj
        let pbxProj = try buildPBXProj(spec: spec, projectRoot: rootPath)

        // 3. 构建 Workspace
        let workspace = XCWorkspace()

        // 4. 构建 XcodeProj
        let xcodeProj = XcodeProj(
            workspace: workspace,
            pbxproj: pbxProj,
            path: nil
        )

        // 5. 如果需要，生成 Schemes
        var sharedData: XCSharedData?
        if options.generateSchemes {
            let schemes = try buildSchemes(spec: spec, pbxproj: pbxProj)
            sharedData = XCSharedData(schemes: schemes)
        }

        // 6. 写出文件
        let xcodeprojPath = rootPath + "\(spec.name).xcodeproj"
        let outputSettings = PBXOutputSettings()
        try xcodeProj.write(path: xcodeprojPath, override: true, outputSettings: outputSettings)

        // 写出 schemes
        if let sharedData {
            try sharedData.write(path: XCSharedData.path(xcodeprojPath), override: true)
        }

        return xcodeprojPath.string
    }

    // MARK: - Validation

    private func validate(spec: XcodeProjectSpec) throws {
        guard !spec.name.isEmpty else {
            throw XcodeProjectGenError.validationError("Project name cannot be empty")
        }
        guard !spec.targets.isEmpty else {
            throw XcodeProjectGenError.validationError("At least one target is required")
        }

        // 检查 Target 名称唯一性
        let names = spec.targets.map(\.name)
        let duplicates = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }
        if !duplicates.isEmpty {
            throw XcodeProjectGenError.validationError("Duplicate target names: \(duplicates.keys.joined(separator: ", "))")
        }

        // 检查 Target 依赖中引用的 Target 是否存在
        for target in spec.targets {
            for dep in target.dependencies {
                if case .target(let name) = dep {
                    guard spec.targets.contains(where: { $0.name == name }) else {
                        throw XcodeProjectGenError.validationError(
                            "Target '\(target.name)' depends on '\(name)', but '\(name)' was not found"
                        )
                    }
                }
            }
        }
    }

    // MARK: - PBXProj Construction

    private func buildPBXProj(
        spec: XcodeProjectSpec,
        projectRoot: Path
    ) throws -> PBXProj {
        let pbxProj = PBXProj(objectVersion: spec.options.objectVersion)

        // --- Main Group ---
        let mainGroup = PBXGroup(
            children: [],
            sourceTree: .group,
            name: spec.name
        )
        pbxProj.add(object: mainGroup)

        // --- Products Group ---
        let productsGroup = PBXGroup(
            children: [],
            sourceTree: .group,
            name: "Products"
        )
        pbxProj.add(object: productsGroup)
        mainGroup.children.append(productsGroup)

        // --- Project Build Configuration List ---
        let projectConfigList = try createConfigurationList(
            name: spec.name,
            projectSettings: spec.settings,
            configurations: spec.configurations,
            pbxProj: pbxProj
        )

        // --- PBXProject ---
        let pbxProject = PBXProject(
            name: spec.name,
            buildConfigurationList: projectConfigList,
            compatibilityVersion: "Xcode \(spec.options.compatibilityVersion)",
            preferredProjectObjectVersion: nil,
            minimizedProjectReferenceProxies: nil,
            mainGroup: mainGroup,
            developmentRegion: "en",
            hasScannedForEncodings: 0,
            knownRegions: ["en", "Base"],
            productsGroup: productsGroup,
            projectDirPath: "",
            projectRoots: [""]
        )
        pbxProj.add(object: pbxProject)
        pbxProj.rootObject = pbxProject

        // --- Track remote packages (去重) ---
        var remotePackageMap: [String: XCRemoteSwiftPackageReference] = [:]

        // --- Create Targets ---
        var targetMap: [String: PBXNativeTarget] = [:]
        var productRefMap: [String: PBXFileReference] = [:]

        for targetSpec in spec.targets {
            let (nativeTarget, productRef) = try createTarget(
                spec: targetSpec,
                pbxProj: pbxProj,
                mainGroup: mainGroup,
                productsGroup: productsGroup,
                projectRoot: projectRoot
            )
            targetMap[targetSpec.name] = nativeTarget
            productRefMap[targetSpec.name] = productRef
            pbxProject.targets.append(nativeTarget)

            // 处理 Swift Package 依赖
            for dep in targetSpec.dependencies {
                switch dep {
                case .remote(let url, let product, let versionRequirement):
                    let packageRef = try addRemotePackage(
                        url: url,
                        versionRequirement: versionRequirement,
                        existingPackages: &remotePackageMap,
                        pbxProj: pbxProj,
                        pbxProject: pbxProject
                    )
                    try linkPackageProduct(
                        packageRef: packageRef,
                        productName: product,
                        target: nativeTarget,
                        pbxProj: pbxProj
                    )

                case .local(let path, let product):
                    try addLocalPackage(
                        path: path,
                        productName: product,
                        target: nativeTarget,
                        pbxProj: pbxProj,
                        mainGroup: mainGroup
                    )

                case .target:
                    // 稍后统一处理 Target 依赖
                    break

                case .framework(let name):
                    try addSystemFramework(
                        name: name,
                        target: nativeTarget,
                        pbxProj: pbxProj
                    )
                }
            }
        }

        // --- 处理 Target 间依赖 ---
        for targetSpec in spec.targets {
            guard let nativeTarget = targetMap[targetSpec.name] else { continue }
            for dep in targetSpec.dependencies {
                if case .target(let depName) = dep {
                    guard let depTarget = targetMap[depName] else {
                        throw XcodeProjectGenError.targetNotFound(depName)
                    }
                    _ = try nativeTarget.addDependency(target: depTarget)
                }
            }
        }

        // --- Target Attributes ---
        for targetSpec in spec.targets {
            guard let nativeTarget = targetMap[targetSpec.name] else { continue }

            var attrs: [String: ProjectAttribute] = [:]

            // Development Team
            if let teamSetting = targetSpec.settings.first(where: {
                if case .developmentTeam = $0 { return true }
                return false
            }), case .developmentTeam(let team) = teamSetting {
                attrs["DevelopmentTeam"] = .string(team)
            }

            if !attrs.isEmpty {
                pbxProject.setTargetAttributes(attrs, target: nativeTarget)
            }
        }

        return pbxProj
    }

    // MARK: - Target Creation

    private func createTarget(
        spec targetSpec: XcodeTargetSpec,
        pbxProj: PBXProj,
        mainGroup: PBXGroup,
        productsGroup: PBXGroup,
        projectRoot: Path
    ) throws -> (PBXNativeTarget, PBXFileReference) {
        // --- Product Reference ---
        let pbxProductType = PBXProductType(rawValue: targetSpec.kind.productType.rawValue)
        let productExtension = pbxProductType?.fileExtension
        let productName = productExtension != nil
            ? "\(targetSpec.name).\(productExtension!)"
            : targetSpec.name

        let productRef = PBXFileReference(
            sourceTree: .buildProductsDir,
            name: productName,
            explicitFileType: pbxProductType?.fileExtension.flatMap {
                Xcode.filetype(extension: $0)
            },
            path: productName
        )
        pbxProj.add(object: productRef)
        productsGroup.children.append(productRef)

        // --- Target Configuration List ---
        let configList = try createConfigurationList(
            name: targetSpec.name,
            targetSpec: targetSpec,
            pbxProj: pbxProj
        )

        // --- Build Phases ---
        let sourcesBuildPhase = PBXSourcesBuildPhase()
        pbxProj.add(object: sourcesBuildPhase)

        var buildPhases: [PBXBuildPhase] = [sourcesBuildPhase]

        // Resources Build Phase（仅当有资源文件时）
        if !targetSpec.resources.isEmpty {
            let resourcesBuildPhase = PBXResourcesBuildPhase()
            pbxProj.add(object: resourcesBuildPhase)
            buildPhases.append(resourcesBuildPhase)
        }

        // Frameworks Build Phase
        let frameworksBuildPhase = PBXFrameworksBuildPhase()
        pbxProj.add(object: frameworksBuildPhase)
        buildPhases.append(frameworksBuildPhase)

        // --- Source Files ---
        for sourcePath in targetSpec.sources {
            try addSourceFiles(
                sourcePath: sourcePath,
                pbxProj: pbxProj,
                mainGroup: mainGroup,
                sourcesBuildPhase: sourcesBuildPhase,
                projectRoot: projectRoot
            )
        }

        // --- Resource Files ---
        if !targetSpec.resources.isEmpty {
            let resourcesPhase = buildPhases.compactMap { $0 as? PBXResourcesBuildPhase }.first
            for resourcePath in targetSpec.resources {
                try addResourceFiles(
                    resourcePath: resourcePath,
                    pbxProj: pbxProj,
                    mainGroup: mainGroup,
                    resourcesBuildPhase: resourcesPhase,
                    projectRoot: projectRoot
                )
            }
        }

        // --- Create Native Target ---
        let nativeTarget = PBXNativeTarget(
            name: targetSpec.name,
            buildConfigurationList: configList,
            buildPhases: buildPhases,
            buildRules: [],
            dependencies: [],
            productName: targetSpec.name,
            product: productRef,
            productType: PBXProductType(rawValue: targetSpec.kind.productType.rawValue)
        )
        pbxProj.add(object: nativeTarget)

        return (nativeTarget, productRef)
    }

    // MARK: - Configuration List

    private func createConfigurationList(
        name: String,
        projectSettings: [XcodeBuildSetting] = [],
        configurations: [XcodeBuildConfigurationSpec] = [],
        pbxProj: PBXProj
    ) throws -> XCConfigurationList {
        let configSpecs = configurations.isEmpty
            ? [.debug(), .release()]
            : configurations

        var buildConfigs: [XCBuildConfiguration] = []
        for configSpec in configSpecs {
            var buildSettings = BuildSettings()

            // 项目级 settings
            for setting in projectSettings {
                let (key, value) = setting.keyValue
                buildSettings[key] = .string(value)
            }

            // 配置级 settings
            for setting in configSpec.settings {
                let (key, value) = setting.keyValue
                buildSettings[key] = .string(value)
            }

            let buildConfig = XCBuildConfiguration(
                name: configSpec.name,
                buildSettings: buildSettings
            )
            pbxProj.add(object: buildConfig)
            buildConfigs.append(buildConfig)
        }

        let configList = XCConfigurationList(
            buildConfigurations: buildConfigs,
            defaultConfigurationName: buildConfigs.first?.name,
            defaultConfigurationIsVisible: false
        )
        pbxProj.add(object: configList)
        return configList
    }

    private func createConfigurationList(
        name: String,
        targetSpec: XcodeTargetSpec,
        pbxProj: PBXProj
    ) throws -> XCConfigurationList {
        let configSpecs = targetSpec.configurations.isEmpty
            ? [.debug(), .release()]
            : targetSpec.configurations

        var buildConfigs: [XCBuildConfiguration] = []
        for configSpec in configSpecs {
            var buildSettings = BuildSettings()

            // 基本设置
            buildSettings["SDKROOT"] = .string(targetSpec.platform.sdkRoot)
            buildSettings[targetSpec.platform.deploymentTargetKey] = .string(targetSpec.deploymentTarget)
            buildSettings["SWIFT_VERSION"] = .string("6.0")
            buildSettings["PRODUCT_NAME"] = .string("$(TARGET_NAME)")
            buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = .string("com.example.\(targetSpec.name)")

            // TARGETED_DEVICE_FAMILY
            if let family = targetSpec.platform.targetedDeviceFamily {
                buildSettings["TARGETED_DEVICE_FAMILY"] = .string(family)
            }

            // Target 全局 settings
            for setting in targetSpec.settings {
                let (key, value) = setting.keyValue
                buildSettings[key] = .string(value)
            }

            // 配置特定 settings
            for setting in configSpec.settings {
                let (key, value) = setting.keyValue
                buildSettings[key] = .string(value)
            }

            // Debug 默认设置
            if configSpec.name == "Debug" {
                if buildSettings["SWIFT_OPTIMIZATION_LEVEL"] == nil {
                    buildSettings["SWIFT_OPTIMIZATION_LEVEL"] = .string("-Onone")
                }
                if buildSettings["ONLY_ACTIVE_ARCH"] == nil {
                    buildSettings["ONLY_ACTIVE_ARCH"] = .string("YES")
                }
                if buildSettings["DEBUG_INFORMATION_FORMAT"] == nil {
                    buildSettings["DEBUG_INFORMATION_FORMAT"] = .string("dwarf")
                }
                if buildSettings["ENABLE_TESTABILITY"] == nil {
                    buildSettings["ENABLE_TESTABILITY"] = .string("YES")
                }
            }

            if configSpec.name == "Release" {
                if buildSettings["DEBUG_INFORMATION_FORMAT"] == nil {
                    buildSettings["DEBUG_INFORMATION_FORMAT"] = .string("dwarf-with-dsym")
                }
            }

            let buildConfig = XCBuildConfiguration(
                name: configSpec.name,
                buildSettings: buildSettings
            )
            pbxProj.add(object: buildConfig)
            buildConfigs.append(buildConfig)
        }

        let configList = XCConfigurationList(
            buildConfigurations: buildConfigs,
            defaultConfigurationName: buildConfigs.first?.name,
            defaultConfigurationIsVisible: false
        )
        pbxProj.add(object: configList)
        return configList
    }

    // MARK: - Source Files

    private func addSourceFiles(
        sourcePath: String,
        pbxProj: PBXProj,
        mainGroup: PBXGroup,
        sourcesBuildPhase: PBXSourcesBuildPhase,
        projectRoot: Path
    ) throws {
        let fullPath = projectRoot + sourcePath

        if fullPath.isDirectory {
            // 递归扫描 Swift 文件
            let swiftFiles = try scanSwiftFiles(in: fullPath)

            // 创建对应的 Group
            let group = PBXGroup(
                children: [],
                sourceTree: .group,
                path: sourcePath
            )
            pbxProj.add(object: group)
            mainGroup.children.append(group)

            for file in swiftFiles {
                let relativePath = XcodeProjectPathUtility.relativePath(
                    for: file.string,
                    rootPath: projectRoot.string,
                    fallbackName: file.lastComponent
                )
                let fileRef = PBXFileReference(
                    sourceTree: .group,
                    name: file.lastComponent,
                    lastKnownFileType: "sourcecode.swift",
                    path: relativePath
                )
                pbxProj.add(object: fileRef)
                group.children.append(fileRef)

                let buildFile = PBXBuildFile(file: fileRef)
                pbxProj.add(object: buildFile)
                sourcesBuildPhase.files?.append(buildFile)
            }
        } else {
            // 单文件
            let relativePath = XcodeProjectPathUtility.relativePath(
                for: fullPath.string,
                rootPath: projectRoot.string,
                fallbackName: fullPath.lastComponent
            )
            let fileRef = PBXFileReference(
                sourceTree: .group,
                name: fullPath.lastComponent,
                lastKnownFileType: "sourcecode.swift",
                path: relativePath
            )
            pbxProj.add(object: fileRef)
            mainGroup.children.append(fileRef)

            let buildFile = PBXBuildFile(file: fileRef)
            pbxProj.add(object: buildFile)
            sourcesBuildPhase.files?.append(buildFile)
        }
    }

    // MARK: - Resource Files

    private func addResourceFiles(
        resourcePath: String,
        pbxProj: PBXProj,
        mainGroup: PBXGroup,
        resourcesBuildPhase: PBXResourcesBuildPhase?,
        projectRoot: Path
    ) throws {
        guard let resourcesBuildPhase else { return }

        let fullPath = projectRoot + resourcePath

        let fileExtension = fullPath.extension ?? ""
        let fileType = Xcode.filetype(extension: fileExtension)

        let relativePath = XcodeProjectPathUtility.relativePath(
            for: fullPath.string,
            rootPath: projectRoot.string,
            fallbackName: fullPath.lastComponent
        )

        let fileRef = PBXFileReference(
            sourceTree: .group,
            name: fullPath.lastComponent,
            lastKnownFileType: fileType,
            path: relativePath
        )
        pbxProj.add(object: fileRef)
        mainGroup.children.append(fileRef)

        let buildFile = PBXBuildFile(file: fileRef)
        pbxProj.add(object: buildFile)
        resourcesBuildPhase.files?.append(buildFile)
    }

    // MARK: - Package Dependencies

    private func addRemotePackage(
        url: String,
        versionRequirement: XcodeVersionRequirement,
        existingPackages: inout [String: XCRemoteSwiftPackageReference],
        pbxProj: PBXProj,
        pbxProject: PBXProject
    ) throws -> XCRemoteSwiftPackageReference {
        if let existing = existingPackages[url] {
            return existing
        }

        let xcodeProjRequirement: XCRemoteSwiftPackageReference.VersionRequirement
        switch versionRequirement {
        case .upToNextMajor(let v):
            xcodeProjRequirement = .upToNextMajorVersion(v)
        case .upToNextMinor(let v):
            xcodeProjRequirement = .upToNextMinorVersion(v)
        case .exact(let v):
            xcodeProjRequirement = .exact(v)
        case .branch(let b):
            xcodeProjRequirement = .branch(b)
        case .revision(let r):
            xcodeProjRequirement = .revision(r)
        }

        let packageRef = XCRemoteSwiftPackageReference(
            repositoryURL: url,
            versionRequirement: xcodeProjRequirement
        )
        pbxProj.add(object: packageRef)
        pbxProject.remotePackages.append(packageRef)
        existingPackages[url] = packageRef

        return packageRef
    }

    private func linkPackageProduct(
        packageRef: XCRemoteSwiftPackageReference,
        productName: String,
        target: PBXNativeTarget,
        pbxProj: PBXProj
    ) throws {
        let productDependency = XCSwiftPackageProductDependency(
            productName: productName,
            package: packageRef
        )
        pbxProj.add(object: productDependency)
        target.packageProductDependencies?.append(productDependency)

        let buildFile = PBXBuildFile(product: productDependency)
        pbxProj.add(object: buildFile)

        guard let frameworksBuildPhase = try target.frameworksBuildPhase() else { return }
        frameworksBuildPhase.files?.append(buildFile)
    }

    private func addLocalPackage(
        path: String,
        productName: String,
        target: PBXNativeTarget,
        pbxProj: PBXProj,
        mainGroup: PBXGroup
    ) throws {
        let productDependency = XCSwiftPackageProductDependency(
            productName: productName
        )
        pbxProj.add(object: productDependency)
        target.packageProductDependencies?.append(productDependency)

        let buildFile = PBXBuildFile(product: productDependency)
        pbxProj.add(object: buildFile)

        guard let frameworksBuildPhase = try target.frameworksBuildPhase() else { return }
        frameworksBuildPhase.files?.append(buildFile)

        // Add file reference
        let fileRef = PBXFileReference(
            sourceTree: .group,
            name: productName,
            lastKnownFileType: "folder",
            path: path
        )
        pbxProj.add(object: fileRef)
        mainGroup.children.append(fileRef)
    }

    private func addSystemFramework(
        name: String,
        target: PBXNativeTarget,
        pbxProj: PBXProj
    ) throws {
        let fileRef = PBXFileReference(
            sourceTree: .sdkRoot,
            name: "\(name).framework",
            lastKnownFileType: "wrapper.framework"
        )
        pbxProj.add(object: fileRef)

        let buildFile = PBXBuildFile(file: fileRef)
        pbxProj.add(object: buildFile)

        guard let frameworksBuildPhase = try target.frameworksBuildPhase() else { return }
        frameworksBuildPhase.files?.append(buildFile)
    }

    // MARK: - Scheme Generation

    private func buildSchemes(
        spec: XcodeProjectSpec,
        pbxproj: PBXProj
    ) throws -> [XCScheme] {
        guard let pbxProject = pbxproj.rootObject else { return [] }

        let schemeSpecs: [XcodeSchemeSpec]
        if spec.schemes.isEmpty {
            // 自动为每个 App Target 生成 Scheme
            schemeSpecs = spec.appTargets.map { target in
                XcodeSchemeSpec(name: target.name, buildTargets: [target.name])
            }
        } else {
            schemeSpecs = spec.schemes
        }

        var schemes: [XCScheme] = []
        for schemeSpec in schemeSpecs {
            let scheme = try buildScheme(
                spec: schemeSpec,
                pbxProject: pbxProject,
                pbxproj: pbxproj
            )
            schemes.append(scheme)
        }
        return schemes
    }

    private func buildScheme(
        spec schemeSpec: XcodeSchemeSpec,
        pbxProject: PBXProject,
        pbxproj: PBXProj
    ) throws -> XCScheme {
        let projectName = pbxProject.name

        // Build Action
        var buildableReferences: [XCScheme.BuildableReference] = []
        for targetName in schemeSpec.buildTargets {
            guard let target = pbxProject.targets.first(where: { $0.name == targetName }) else { continue }
            let productExt = target.productType?.fileExtension ?? "app"
            let buildableName = "\(targetName).\(productExt)"

            let buildableRef = XCScheme.BuildableReference(
                referencedContainer: "container:\(projectName).xcodeproj",
                blueprint: target,
                buildableName: buildableName,
                blueprintName: targetName
            )
            buildableReferences.append(buildableRef)
        }

        guard let primaryRef = buildableReferences.first else {
            throw XcodeProjectGenError.validationError("No buildable references for scheme '\(schemeSpec.name)'")
        }

        let buildActionEntries = buildableReferences.map {
            XCScheme.BuildAction.Entry(buildableReference: $0, buildFor: [.running, .testing, .archiving, .analyzing])
        }

        let buildAction = XCScheme.BuildAction(
            buildActionEntries: buildActionEntries,
            preActions: [],
            postActions: [],
            parallelizeBuild: true,
            buildImplicitDependencies: true
        )

        let launchRunnable = XCScheme.BuildableProductRunnable(buildableReference: primaryRef)

        let launchAction = XCScheme.LaunchAction(
            runnable: launchRunnable,
            buildConfiguration: schemeSpec.runConfiguration,
            preActions: [],
            postActions: [],
            macroExpansion: nil,
            selectedDebuggerIdentifier: XCScheme.defaultDebugger,
            selectedLauncherIdentifier: XCScheme.defaultLauncher
        )

        let testAction = XCScheme.TestAction(
            buildConfiguration: schemeSpec.testConfiguration,
            macroExpansion: nil,
            testables: [],
            preActions: [],
            postActions: []
        )

        let profileAction = XCScheme.ProfileAction(
            buildableProductRunnable: launchRunnable,
            buildConfiguration: schemeSpec.profileConfiguration,
            preActions: [],
            postActions: []
        )

        let analyzeAction = XCScheme.AnalyzeAction(
            buildConfiguration: schemeSpec.analyzeConfiguration
        )

        let archiveAction = XCScheme.ArchiveAction(
            buildConfiguration: schemeSpec.archiveConfiguration,
            revealArchiveInOrganizer: true,
            preActions: [],
            postActions: []
        )

        return XCScheme(
            name: schemeSpec.name,
            lastUpgradeVersion: nil,
            version: Xcode.Default.xcschemeFormatVersion,
            buildAction: buildAction,
            testAction: testAction,
            launchAction: launchAction,
            profileAction: profileAction,
            analyzeAction: analyzeAction,
            archiveAction: archiveAction
        )
    }

    // MARK: - File Scanning

    private func scanSwiftFiles(in directory: Path) throws -> [Path] {
        guard directory.isDirectory else {
            throw XcodeProjectGenError.scanFailed("Not a directory: \(directory.string)")
        }

        var files: [Path] = []
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(atPath: directory.string) else {
            throw XcodeProjectGenError.scanFailed("Cannot enumerate directory: \(directory.string)")
        }

        for case let item as String in enumerator {
            if item.hasSuffix(".swift") {
                files.append(directory + item)
            }
        }

        return files.sorted { $0.string < $1.string }
    }
}
