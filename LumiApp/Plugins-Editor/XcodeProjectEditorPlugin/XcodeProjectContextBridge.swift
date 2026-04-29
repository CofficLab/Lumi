import Foundation
import os
import MagicKit

/// Xcode Project Context Bridge
/// 职责：在 XcodeProjectEditorPlugin 和 LSPService 之间建立连接
/// 对应 Roadmap Phase 4: SourceKit-LSP Integration Hardening
@MainActor
final class XcodeProjectContextBridge: SuperLog {
    
    nonisolated static let emoji = "🔗"
    nonisolated static let verbose = true
    static let shared = XcodeProjectContextBridge()
    
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.bridge")
    
    /// build context provider 引用
    private var _buildContextProvider: Any?
    
    /// 项目根路径
    private var currentProjectPath: String?
    
    /// 是否已初始化
    var isInitialized: Bool = false
    
    /// 当前项目是否为 Xcode 项目
    var isXcodeProject: Bool = false
    
    /// 缓存的状态快照（供非主线程安全访问）
    private(set) var cachedState: BridgeCachedState?
    
    /// buildServer.json 路径
    var buildServerJSONPath: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.buildServerJSONPath } }
    
    /// active scheme
    var activeScheme: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.activeScheme?.name } }
    
    private init() {}
    
    // MARK: - 注册 Build Context Provider
    
    func registerBuildContextProvider(_ provider: XcodeBuildContextProvider) {
        _buildContextProvider = provider
        Self.logger.info("\(Self.t)BuildContextProvider 已注册")
    }
    
    var buildContextProvider: XcodeBuildContextProvider? {
        _buildContextProvider as? XcodeBuildContextProvider
    }
    
    // MARK: - 项目打开
    
    func projectOpened(at path: String) async {
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
        Self.logger.info("\(Self.t)项目已关闭，build context 已失效")
    }
    
    // MARK: - Cache
    
    @MainActor
    private func updateCache() {
        let state = BridgeCachedState(
            workspaceFolders: makeWorkspaceFoldersInternal(),
            buildServerPath: buildServerJSONPath,
            activeScheme: activeScheme,
            buildContextStatus: buildContextProvider?.buildContextStatus.displayDescription ?? "未初始化",
            isXcodeProject: isXcodeProject,
            isInitialized: isInitialized
        )
        cachedState = state
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
        return options.isEmpty ? nil : options
    }
}

/// 缓存状态快照（Sendable，供非主线程安全访问）
struct BridgeCachedState: Sendable {
    let workspaceFolders: [[String: String]]?
    let buildServerPath: String?
    let activeScheme: String?
    let buildContextStatus: String
    let isXcodeProject: Bool
    let isInitialized: Bool
}
