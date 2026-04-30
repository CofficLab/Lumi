import Foundation
import Combine
import os
import MagicKit

/// Xcode Project Context Bridge
/// 职责：在 XcodeProjectEditorPlugin 和 LSPService 之间建立连接
@MainActor
final class XcodeProjectContextBridge: SuperLog {
    
    nonisolated static let emoji = "🔗"
    nonisolated static let verbose = true
    static let shared = XcodeProjectContextBridge()
    
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.bridge")
    
    /// build context provider 引用
    private var _buildContextProvider: Any?
    private var cancellables = Set<AnyCancellable>()
    
    /// 项目根路径
    private var currentProjectPath: String?
    
    /// 是否已初始化
    var isInitialized: Bool = false
    
    /// 当前项目是否为 Xcode 项目
    var isXcodeProject: Bool = false
    
    /// 缓存的状态快照（供非主线程安全访问）
    private(set) var cachedState: BridgeCachedState?
    private(set) var latestEditorSnapshot: XcodeEditorContextSnapshot?
    
    /// buildServer.json 路径
    var buildServerJSONPath: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.buildServerJSONPath } }
    
    /// active scheme
    var activeScheme: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.activeScheme?.name } }
    
    /// active configuration
    var activeConfiguration: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.activeConfiguration } }
    
    /// active destination
    var activeDestination: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.activeDestination?.name } }
    var activeDestinationQuery: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.activeDestination?.destinationQuery } }
    
    private init() {}
    
    // MARK: - 注册 Build Context Provider
    
    func registerBuildContextProvider(_ provider: XcodeBuildContextProvider) {
        _buildContextProvider = provider
        cancellables.removeAll()
        provider.$currentWorkspace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCache()
            }
            .store(in: &cancellables)
        provider.$activeScheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCache()
            }
            .store(in: &cancellables)
        provider.$activeDestination
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCache()
            }
            .store(in: &cancellables)
        provider.$buildContextStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCache()
            }
            .store(in: &cancellables)
        provider.$buildServerJSONPath
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCache()
            }
            .store(in: &cancellables)
        Self.logger.info("\(Self.t)BuildContextProvider 已注册")
        updateCache()
    }
    
    var buildContextProvider: XcodeBuildContextProvider? {
        _buildContextProvider as? XcodeBuildContextProvider
    }
    
    // MARK: - 项目打开
    
    func projectOpened(at path: String) async {
        if currentProjectPath == path, isInitialized {
            updateCache()
            return
        }
        currentProjectPath = path
        let projectURL = URL(filePath: path)
        let isXcodeProject = XcodeProjectResolver.isXcodeProjectRoot(projectURL)
        self.isXcodeProject = isXcodeProject
        
        Self.logger.info("\(Self.t)项目已打开: \(path, privacy: .public), 是 Xcode 项目: \(isXcodeProject)")
        
        if isXcodeProject {
            await initializeXcodeBuildContext(at: path)
        }
        
        isInitialized = true
        updateCache()
    }
    
    func projectClosed() {
        currentProjectPath = nil
        isXcodeProject = false
        isInitialized = false
        
        if let provider = _buildContextProvider as? XcodeBuildContextProvider {
            provider.invalidateAllContexts()
        }
        
        cachedState = nil
        latestEditorSnapshot = nil
        Self.logger.info("\(Self.t)项目已关闭，build context 已失效")
    }

    func resyncBuildContext() async {
        guard let currentProjectPath, isXcodeProject else { return }
        guard let provider = _buildContextProvider as? XcodeBuildContextProvider else { return }

        Self.logger.info("\(Self.t)手动触发 build context 重解析: \(currentProjectPath, privacy: .public)")
        provider.invalidateAllContexts()
        await initializeXcodeBuildContext(at: currentProjectPath)
        isInitialized = true
        updateCache()
    }
    
    // MARK: - Cache
    
    @MainActor
    private func updateCache() {
        let schemes = buildContextProvider?.currentWorkspace?.schemes.map(\.name) ?? []
        let configurations = buildContextProvider?.currentWorkspace?.projects.flatMap(\.buildConfigurations).map(\.name) ?? []
        let state = BridgeCachedState(
            workspaceFolders: makeWorkspaceFoldersInternal(),
            buildServerPath: buildServerJSONPath,
            activeScheme: activeScheme,
            activeConfiguration: activeConfiguration,
            activeDestination: activeDestination,
            buildContextStatus: buildContextProvider?.buildContextStatus.displayDescription ?? "未初始化",
            isXcodeProject: isXcodeProject,
            isInitialized: isInitialized,
            workspaceName: buildContextProvider?.currentWorkspace?.name,
            workspacePath: buildContextProvider?.currentWorkspace?.path.path,
            schemes: schemes,
            configurations: Array(Set(configurations)).sorted(),
            projectPath: currentProjectPath
        )
        cachedState = state
        NotificationCenter.default.post(name: .lumiEditorProjectContextDidChange, object: nil)
        NotificationCenter.default.post(name: .lumiEditorXcodeContextDidChange, object: nil)
    }
    
    // MARK: - Build Context 初始化
    
    private func initializeXcodeBuildContext(at path: String) async {
        guard let provider = _buildContextProvider as? XcodeBuildContextProvider else {
            Self.logger.warning("\(Self.t)BuildContextProvider 未注册，跳过初始化")
            return
        }
        
        let projectURL = URL(filePath: path)
        if isBuildServerValid(at: path) {
            if let workspaceURL = XcodeProjectResolver.findWorkspace(in: projectURL) {
                await provider.openProject(at: workspaceURL)
                Self.logger.info("\(Self.t)使用已有的 buildServer.json")
            }
            return
        }
        await provider.openProject(at: projectURL)
    }
    
    private func isBuildServerValid(at path: String) -> Bool {
        let projectURL = URL(filePath: path)
        let buildServerURL: URL
        if let workspaceURL = XcodeProjectResolver.findWorkspace(in: projectURL) {
            buildServerURL = workspaceURL.deletingLastPathComponent().appendingPathComponent("buildServer.json")
        } else {
            buildServerURL = projectURL.appendingPathComponent("buildServer.json")
        }
        guard FileManager.default.fileExists(atPath: buildServerURL.path),
              let data = try? Data(contentsOf: buildServerURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              let scheme = json["scheme"] as? String else { return false }
        return name.contains("xcode build server") && !scheme.isEmpty
    }
    
    // MARK: - LSP 参数生成
    
    /// 为 sourcekit-lsp 生成 workspaceFolders 参数
    func makeWorkspaceFolders() -> [[String: String]]? {
        cachedState?.workspaceFolders
    }
    
    private func makeWorkspaceFoldersInternal() -> [[String: String]]? {
        guard isXcodeProject, let projectPath = currentProjectPath else { return nil }
        let projectURL = URL(filePath: projectPath)
        guard let workspaceURL = XcodeProjectResolver.findWorkspace(in: projectURL) else { return nil }
        let rootURL = workspaceURL.deletingLastPathComponent()
        return [["uri": "file://" + rootURL.path, "name": workspaceURL.deletingPathExtension().lastPathComponent]]
    }
    
    func getBuildServerPath() -> String? { cachedState?.buildServerPath }
    var cachedActiveScheme: String? { cachedState?.activeScheme }
    var buildContextStatusDescription: String { cachedState?.buildContextStatus ?? "未初始化" }
    var shouldHaveBuildContext: Bool { cachedState?.isXcodeProject ?? false }
    
    func makeInitializationOptions() -> [String: Any]? {
        guard shouldHaveBuildContext else { return nil }
        var options: [String: Any] = [:]
        if let buildServerPath = getBuildServerPath() { options["buildServerPath"] = buildServerPath }
        if let scheme = cachedActiveScheme { options["scheme"] = scheme }
        if let configuration = cachedState?.activeConfiguration { options["configuration"] = configuration }
        if let destination = activeDestinationQuery { options["destination"] = destination }
        return options.isEmpty ? nil : options
    }

    func makeEditorContextSnapshot(currentFileURL: URL? = nil) -> XcodeEditorContextSnapshot? {
        guard let cachedState else { return nil }
        let workspaceName = cachedState.workspaceName ?? URL(filePath: cachedState.projectPath ?? "").deletingPathExtension().lastPathComponent
        let buildableTargets = buildContextProvider?.activeScheme?.buildableTargets ?? []
        let preferredTarget = currentFileURL.flatMap { fileURL in
            buildContextProvider?.resolvePreferredTarget(for: fileURL)?.name
        }
        let matchedTargets = currentFileURL.flatMap { fileURL in
            buildContextProvider?.findTargetsForFile(fileURL: fileURL).map(\.name).sorted()
        } ?? []
        return XcodeEditorContextSnapshot(
            projectPath: cachedState.projectPath ?? "",
            workspaceName: workspaceName,
            workspacePath: cachedState.workspacePath ?? cachedState.projectPath ?? "",
            activeScheme: cachedState.activeScheme,
            activeSchemeBuildableTargets: buildableTargets,
            activeConfiguration: cachedState.activeConfiguration,
            activeDestination: cachedState.activeDestination,
            buildContextStatus: cachedState.buildContextStatus,
            isXcodeProject: cachedState.isXcodeProject,
            schemes: cachedState.schemes,
            configurations: cachedState.configurations,
            currentFilePath: currentFileURL?.path,
            currentFileTarget: preferredTarget,
            currentFileMatchedTargets: matchedTargets,
            currentFileIsInTarget: !matchedTargets.isEmpty
        )
    }

    func updateLatestEditorSnapshot(_ snapshot: XcodeEditorContextSnapshot?) {
        guard latestEditorSnapshot != snapshot else { return }
        latestEditorSnapshot = snapshot
        NotificationCenter.default.post(name: .lumiEditorXcodeSnapshotDidChange, object: nil)
    }
}

/// 缓存状态快照（Sendable，供非主线程安全访问）
struct BridgeCachedState: Sendable {
    let workspaceFolders: [[String: String]]?
    let buildServerPath: String?
    let activeScheme: String?
    let activeConfiguration: String?
    let activeDestination: String?
    let buildContextStatus: String
    let isXcodeProject: Bool
    let isInitialized: Bool
    let workspaceName: String?
    let workspacePath: String?
    let schemes: [String]
    let configurations: [String]
    let projectPath: String?
}
