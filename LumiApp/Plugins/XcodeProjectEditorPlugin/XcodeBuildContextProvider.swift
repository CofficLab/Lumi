import Foundation
import os
import MagicKit

/// Xcode Build Context Provider
/// 对应 Roadmap Phase 3
/// 职责：
/// 1. 生成/管理 buildServer.json
/// 2. 提供文件到 build context 的映射
/// 3. 缓存 build settings
/// 4. 处理 context invalidation
@MainActor
final class XcodeBuildContextProvider: SuperLog, ObservableObject {
    
    nonisolated static let emoji = "🏗️"
    nonisolated static let verbose = true
    
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.buildcontext")
    
    // MARK: - Published State
    
    @Published private(set) var currentWorkspace: XcodeWorkspaceContext?
    @Published private(set) var activeScheme: XcodeSchemeContext?
    @Published private(set) var activeConfiguration: String?
    @Published private(set) var activeDestination: XcodeDestinationContext?
    @Published var buildContextStatus: BuildContextStatus = .unknown
    
    @Published private(set) var buildServerJSONPath: String?
    @Published private(set) var isGeneratingBuildServer: Bool = false
    
    // MARK: - Cache
    
    /// build settings 缓存: cacheKey → settings
    private var buildSettingsCache: [String: [[String: String]]] = [:]
    
    /// xcode-build-server 路径缓存
    private var xcodeBuildServerPath: String?
    
    // MARK: - 解析器
    
    private let resolver = XcodeProjectResolver()
    
    // MARK: - 状态枚举
    
    /// Build context 状态（对应 Phase 8：需要 UI 可见）
    enum BuildContextStatus: Sendable {
        case unknown
        case resolving
        case available(XcodeBuildServerConfig)
        case unavailable(String)
        case needsResync
        
        /// 人类可读的状态描述
        var displayDescription: String {
            switch self {
            case .unknown:
                return "未知"
            case .resolving:
                return "正在解析 build context..."
            case .available(let config):
                return "可用 (scheme: \(config.scheme))"
            case .unavailable(let reason):
                return "不可用: \(reason)"
            case .needsResync:
                return "需要重新同步"
            }
        }
    }
    
    struct XcodeBuildServerConfig {
        let buildServerJSONPath: String
        let workspacePath: String
        let scheme: String
    }
    
    // MARK: - 初始化
    
    init() {
        locateXcodeBuildServer()
    }
    
    // MARK: - 核心方法
    
    /// 打开/识别一个 Xcode 项目
    func openProject(at projectURL: URL) async {
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            buildContextStatus = .unavailable("项目路径不存在: \(projectURL.path)")
            return
        }
        
        let workspaceURL = XcodeProjectResolver.findWorkspace(in: projectURL)
        guard let workspaceURL else {
            buildContextStatus = .unavailable("未找到 .xcodeproj / .xcworkspace")
            return
        }
        
        buildContextStatus = .resolving
        
        // 解析项目
        guard let workspaceContext = await resolver.resolve(workspaceURL: workspaceURL) else {
            buildContextStatus = .unavailable("无法解析项目")
            return
        }
        
        currentWorkspace = workspaceContext
        if currentWorkspace?.activeDestination == nil {
            currentWorkspace?.activeDestination = Self.defaultDestination()
        }
        activeDestination = currentWorkspace?.activeDestination
        
        // 自动选择最佳 scheme：优先选择与项目同名的 scheme（通常是主 target），
        // 其次选择与 target 同名的 scheme，最后才 fallback 到第一个
        let bestScheme = Self.selectBestScheme(
            schemes: workspaceContext.schemes,
            projectName: workspaceContext.name,
            targets: workspaceContext.projects.flatMap { $0.targets.map(\.name) }
        )
        if let bestScheme {
            await setActiveScheme(bestScheme)
        }
    }
    
    /// 设置 active scheme
    func setActiveScheme(_ scheme: XcodeSchemeContext) async {
        guard let workspace = currentWorkspace else { return }
        var resolvedScheme = scheme
        if resolvedScheme.activeConfiguration.isEmpty {
            resolvedScheme.activeConfiguration = resolvedScheme.defaultConfiguration ?? "Debug"
        }
        if resolvedScheme.activeDestination == nil {
            resolvedScheme.activeDestination = activeDestination ?? currentWorkspace?.activeDestination ?? Self.defaultDestination()
        }
        
        Self.logger.info("\(Self.t)切换 Scheme: \(resolvedScheme.name, privacy: .public)")
        
        activeScheme = resolvedScheme
        activeConfiguration = resolvedScheme.activeConfiguration
        activeDestination = resolvedScheme.activeDestination
        currentWorkspace?.activeScheme = resolvedScheme
        currentWorkspace?.activeDestination = resolvedScheme.activeDestination
        
        // 清除旧缓存
        buildSettingsCache.removeAll()
        
        // 重新生成 buildServer.json
        await generateBuildServerJSON(
            workspaceURL: workspace.path,
            scheme: resolvedScheme.name
        )
    }
    
    /// 设置 active configuration
    func setActiveConfiguration(_ configurationName: String) async {
        guard var scheme = activeScheme else { return }
        scheme.activeConfiguration = configurationName
        activeScheme = scheme
        activeConfiguration = configurationName
        currentWorkspace?.activeScheme = scheme
        
        // 清除缓存
        buildSettingsCache.removeAll()
        
        // 重新生成
        if let workspace = currentWorkspace {
            await generateBuildServerJSON(
                workspaceURL: workspace.path,
                scheme: scheme.name
            )
        }
    }
    
    // MARK: - buildServer.json 管理
    
    /// 生成 buildServer.json
    /// 返回 JSON 路径，如果失败返回 nil
    func generateBuildServerJSON(workspaceURL: URL, scheme: String) async {
        guard let serverPath = xcodeBuildServerPath else {
            buildContextStatus = .unavailable("未安装 xcode-build-server，请运行: brew install xcode-build-server")
            return
        }
        
        isGeneratingBuildServer = true
        
        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"
        
        let args = [
            serverPath, "config",
            workspaceArg, workspaceURL.path,
            "-scheme", scheme
        ]
        
        Self.logger.info("\(Self.t)生成 buildServer.json: \(args.joined(separator: " "), privacy: .public)")
        
        // 关键：xcode-build-server config 会把 buildServer.json 生成到当前工作目录，
        // 必须设置 currentDirectoryURL 为项目根目录（workspace/project 的父目录）
        let outputDirectory = workspaceURL.deletingLastPathComponent()
        let success = await runCommand(
            path: serverPath,
            args: ["config", workspaceArg, workspaceURL.path, "-scheme", scheme],
            workingDirectory: outputDirectory
        )
        
        isGeneratingBuildServer = false
        
        if success {
            let jsonPath = outputDirectory.appendingPathComponent("buildServer.json").path
            buildServerJSONPath = jsonPath
            
            if let config = buildServerConfig(from: jsonPath) {
                buildContextStatus = .available(config)
                Self.logger.info("\(Self.t)buildServer.json 已生成: \(jsonPath, privacy: .public)")
            }
        } else {
            buildContextStatus = .unavailable("生成 buildServer.json 失败")
        }
    }
    
    /// 读取并解析 buildServer.json
    func buildServerConfig(from path: String) -> XcodeBuildServerConfig? {
        let url = URL(filePath: path)
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let workspacePath = json["workspace"] as? String ?? ""
        let scheme = json["scheme"] as? String ?? ""
        
        return XcodeBuildServerConfig(
            buildServerJSONPath: path,
            workspacePath: workspacePath,
            scheme: scheme
        )
    }
    
    // MARK: - 文件归属查询
    
    /// 查询文件属于哪个 target
    func findTargetForFile(fileURL: URL) -> XcodeTargetContext? {
        resolvePreferredTarget(for: fileURL)
    }

    /// 查询文件属于哪些 target
    func findTargetsForFile(fileURL: URL) -> [XcodeTargetContext] {
        guard let workspace = currentWorkspace else { return [] }
        
        let filePath = fileURL.path
        var matches: [XcodeTargetContext] = []
        for project in workspace.projects {
            for target in project.targets {
                if target.sourceFiles.contains(filePath) {
                    matches.append(target)
                }
            }
        }
        return matches
    }

    func resolvePreferredTarget(for fileURL: URL) -> XcodeTargetContext? {
        let matches = findTargetsForFile(fileURL: fileURL)
        guard !matches.isEmpty else { return nil }
        if matches.count == 1 {
            return matches[0]
        }
        if let activeScheme {
            if let exactMatch = matches.first(where: { $0.name == activeScheme.name }) {
                return exactMatch
            }
            let buildableMatches = matches.filter { activeScheme.buildableTargets.contains($0.name) }
            if buildableMatches.count == 1 {
                return buildableMatches[0]
            }
        }
        return nil
    }

    func targetsCompatibleWithActiveScheme(for fileURL: URL) -> [XcodeTargetContext] {
        let matches = findTargetsForFile(fileURL: fileURL)
        guard let activeScheme else { return matches }
        return matches.filter { activeScheme.buildableTargets.contains($0.name) || $0.name == activeScheme.name }
    }
    
    /// 获取文件的编译上下文（供 LSP 使用）
    func buildContextForFile(fileURL: URL) async -> XcodeFileBuildContext? {
        guard let workspace = currentWorkspace,
              let scheme = activeScheme else { return nil }
        let configuration = activeConfiguration ?? scheme.activeConfiguration
        let matchedTargets = findTargetsForFile(fileURL: fileURL).map(\.name)
        let destination = activeDestination?.destinationQuery ?? scheme.activeDestination?.destinationQuery
        
        // 先从缓存查找
        let cacheKey = "\(workspace.id)|\(scheme.name)|\(configuration)|\(destination ?? "default")"
        if let cached = buildSettingsCache[cacheKey], !cached.isEmpty {
            let selectedSettings = selectBuildSettings(from: cached, preferredTargetNames: matchedTargets) ?? cached.first!
            updateActiveDestination(using: selectedSettings)
            return XcodeFileBuildContext(
                fileURL: fileURL,
                settings: selectedSettings,
                scheme: scheme.name,
                workspacePath: workspace.rootURL.path
            )
        }
        
        // 实时获取
        let workspaceURL = workspace.path.pathExtension == "xcworkspace" ? workspace.path : nil
        let projectURL = workspace.path.pathExtension == "xcodeproj" ? workspace.path : workspace.projects.first?.path
        let settings = await resolver.fetchBuildSettings(
            workspaceURL: workspaceURL,
            projectURL: projectURL,
            scheme: scheme.name,
            configuration: configuration,
            destination: destination
        )
        
        guard let settings = settings, !settings.isEmpty else { return nil }
        
        buildSettingsCache[cacheKey] = settings
        let selectedSettings = selectBuildSettings(from: settings, preferredTargetNames: matchedTargets) ?? settings.first!
        updateActiveDestination(using: selectedSettings)
        
        return XcodeFileBuildContext(
            fileURL: fileURL,
            settings: selectedSettings,
            scheme: scheme.name,
            workspacePath: workspace.rootURL.path
        )
    }
    
    // MARK: - Context Invalidation
    
    /// 使所有缓存失效
    func invalidateAllContexts() {
        buildSettingsCache.removeAll()
        buildContextStatus = .needsResync
        Self.logger.info("\(Self.t)所有 build context 已失效")
    }
    
    /// 使特定 scheme 的缓存失效
    func invalidateContext(for schemeName: String) {
        buildSettingsCache = buildSettingsCache.filter { key, _ in
            !key.contains(schemeName)
        }
        Self.logger.info("\(Self.t)Scheme '\(schemeName, privacy: .public)' 的 build context 已失效")
    }
    
    // MARK: - Scheme 智能选择
    
    /// 选择最佳 scheme
    /// 优先级：
    /// 1. 与项目名同名的 scheme（如 Lumi 项目选 Lumi scheme）
    /// 2. 与某个 target 同名的 scheme
    /// 3. 排除已知依赖包 scheme 后的第一个
    /// 4. 第一个 scheme（兜底）
    static func selectBestScheme(
        schemes: [XcodeSchemeContext],
        projectName: String,
        targets: [String]
    ) -> XcodeSchemeContext? {
        guard !schemes.isEmpty else { return nil }
        
        // 1. 优先：与项目同名的 scheme
        if let match = schemes.first(where: { $0.name == projectName }) {
            logger.info("\(Self.t)自动选择 Scheme（与项目同名）: \(match.name, privacy: .public)")
            return match
        }
        
        // 2. 其次：与某个 target 同名的 scheme（排除 Package scheme）
        let nonPackageTargets = targets.filter { !$0.hasSuffix("-Package") }
        for target in nonPackageTargets {
            if let match = schemes.first(where: { $0.name == target }) {
                logger.info("\(Self.t)自动选择 Scheme（与 target 同名）: \(match.name, privacy: .public)")
                return match
            }
        }
        
        // 3. 排除已知的依赖包 scheme
        let dependencySuffixes = ["-Package", "-Testing", "Testing"]
        let dependencyPrefixes = ["SwiftTreeSitter", "Semaphore"]
        let isKnownDependency: (String) -> Bool = { name in
            dependencySuffixes.contains(where: { name.hasSuffix($0) }) ||
            dependencyPrefixes.contains(where: { name.hasPrefix($0) }) ||
            name == "CodeEditLanguages" || name == "TextStory"
        }
        
        if let match = schemes.first(where: { !isKnownDependency($0.name) }) {
            logger.info("\(Self.t)自动选择 Scheme（排除依赖包后）: \(match.name, privacy: .public)")
            return match
        }
        
        // 4. 兜底
        let fallback = schemes[0]
        logger.info("\(Self.t)自动选择 Scheme（兜底）: \(fallback.name, privacy: .public)")
        return fallback
    }

    static func defaultDestination() -> XcodeDestinationContext {
        XcodeDestinationContext.macOSDefault()
    }
    
    // MARK: - 工具方法
    
    /// 查找 xcode-build-server 路径
    private func locateXcodeBuildServer() {
        let paths = [
            "/opt/homebrew/bin/xcode-build-server",
            "/usr/local/bin/xcode-build-server",
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                xcodeBuildServerPath = path
                Self.logger.info("\(Self.t)找到 xcode-build-server: \(path, privacy: .public)")
                return
            }
        }
        
        // 尝试 PATH
        if let path = try? runShellCommand("which", args: ["xcode-build-server"])?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            xcodeBuildServerPath = path
        }
    }
    
    /// 执行命令
    /// - Parameters:
    ///   - path: 可执行文件路径
    ///   - args: 命令参数
    ///   - workingDirectory: 工作目录，xcode-build-server config 会将 buildServer.json 生成到此目录
    private func runCommand(path: String, args: [String], workingDirectory: URL? = nil) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: path)
            process.arguments = args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            if let workingDirectory {
                process.currentDirectoryURL = workingDirectory
            }
            
            process.terminationHandler = { _ in
                continuation.resume(returning: process.terminationStatus == 0)
            }
            
            do {
                try process.run()
            } catch {
                Self.logger.error("\(Self.t)命令执行失败: \(error.localizedDescription, privacy: .public)")
                continuation.resume(returning: false)
            }
        }
    }
    
    private func runShellCommand(_ path: String, args: [String]) throws -> String? {
        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func updateActiveDestination(using settings: [String: String]) {
        let derived = deriveDestination(from: settings)
        guard activeDestination != derived else { return }
        activeDestination = derived
        currentWorkspace?.activeDestination = derived
        if var scheme = activeScheme {
            scheme.activeDestination = derived
            activeScheme = scheme
            currentWorkspace?.activeScheme = scheme
        }
    }

    private func deriveDestination(from settings: [String: String]) -> XcodeDestinationContext {
        let platformName = settings["PLATFORM_NAME"] ?? settings["EFFECTIVE_PLATFORM_NAME"] ?? "macosx"
        let sdkRoot = settings["SDKROOT"] ?? platformName
        let arch = settings["NATIVE_ARCH_64_BIT"] ?? settings["ARCHS"]?.split(separator: " ").first.map(String.init)

        let platform: String
        let name: String
        if sdkRoot.contains("iphoneos") || platformName.contains("iphoneos") {
            platform = "iOS"
            name = arch.map { "Any iPhone Device (\($0))" } ?? "Any iPhone Device"
        } else if sdkRoot.contains("iphonesimulator") || platformName.contains("iphonesimulator") {
            platform = "iOS Simulator"
            name = arch.map { "Any iOS Simulator (\($0))" } ?? "Any iOS Simulator"
        } else if sdkRoot.contains("appletvosimulator") || platformName.contains("appletvsimulator") {
            platform = "tvOS Simulator"
            name = arch.map { "Any tvOS Simulator (\($0))" } ?? "Any tvOS Simulator"
        } else if sdkRoot.contains("appletvos") || platformName.contains("appletvos") {
            platform = "tvOS"
            name = arch.map { "Any Apple TV Device (\($0))" } ?? "Any Apple TV Device"
        } else if sdkRoot.contains("watchsimulator") || platformName.contains("watchsimulator") {
            platform = "watchOS Simulator"
            name = arch.map { "Any watchOS Simulator (\($0))" } ?? "Any watchOS Simulator"
        } else if sdkRoot.contains("watchos") || platformName.contains("watchos") {
            platform = "watchOS"
            name = arch.map { "Any Apple Watch Device (\($0))" } ?? "Any Apple Watch Device"
        } else {
            platform = "macOS"
            name = arch.map { "My Mac (\($0))" } ?? "My Mac"
        }

        return XcodeDestinationContext(
            id: "\(platform)-\(arch ?? "default")",
            platform: platform,
            arch: arch,
            name: name,
            destinationQuery: destinationQuery(forPlatform: platform, arch: arch)
        )
    }

    private func destinationQuery(forPlatform platform: String, arch: String?) -> String {
        let queryPlatform: String
        switch platform {
        case "iOS":
            queryPlatform = "iOS"
        case "iOS Simulator":
            queryPlatform = "iOS Simulator"
        case "tvOS":
            queryPlatform = "tvOS"
        case "tvOS Simulator":
            queryPlatform = "tvOS Simulator"
        case "watchOS":
            queryPlatform = "watchOS"
        case "watchOS Simulator":
            queryPlatform = "watchOS Simulator"
        default:
            queryPlatform = "macOS"
        }
        if let arch, !arch.isEmpty {
            return "platform=\(queryPlatform),arch=\(arch)"
        }
        return "platform=\(queryPlatform)"
    }

    private func selectBuildSettings(
        from settingsList: [[String: String]],
        preferredTargetNames: [String]
    ) -> [String: String]? {
        guard !preferredTargetNames.isEmpty else { return settingsList.first }
        return settingsList.first { settings in
            guard let targetName = settings["TARGET_NAME"] else { return false }
            return preferredTargetNames.contains(targetName)
        } ?? settingsList.first
    }
}

// MARK: - Xcode File Build Context

/// 单个文件的编译上下文
struct XcodeFileBuildContext: Sendable {
    let fileURL: URL
    let settings: [String: String]
    let scheme: String
    let workspacePath: String
    
    /// 提取 SDK 路径
    var sdkPath: String? { settings["SDKROOT"] }
    
    /// 提取 toolchain 路径
    var toolchainPath: String? { settings["TOOLCHAIN_DIR"] }
    
    /// 提取 target triple
    var targetTriple: String? { settings["LLVM_TARGET_TRIPLE_SUFFIX"] }
    
    /// 提取 header search paths
    var headerSearchPaths: [String] {
        (settings["HEADER_SEARCH_PATHS"] ?? "")
            .split(separator: " ")
            .map(String.init)
    }
    
    /// 提取 framework search paths
    var frameworkSearchPaths: [String] {
        (settings["FRAMEWORK_SEARCH_PATHS"] ?? "")
            .split(separator: " ")
            .map(String.init)
    }
    
    /// 提取 active compilation conditions
    var activeCompilationConditions: [String] {
        (settings["ACTIVE_COMPILATION_CONDITIONS"] ?? "")
            .split(separator: " ")
            .map(String.init)
    }
    
    /// 提取 module name
    var moduleName: String? { settings["PRODUCT_MODULE_NAME"] }
}
