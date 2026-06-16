import Foundation
import Combine
import os
import SuperLogKit

/// Xcode Project Context Bridge
/// 职责：在 XcodeProjectEditorPlugin 和 LSPService 之间建立连接
///
/// 同时实现 `XcodeContextProviding` 协议，供 `XcodeSemanticAvailability` 等核心逻辑使用。
@MainActor
final public class XcodeProjectContextBridge: SuperLog, XcodeContextProviding {

    nonisolated public static let emoji = "🔗"
    nonisolated public static let verbose = false
    public static let shared = XcodeProjectContextBridge()

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.bridge")

    /// build context provider 引用
    private var _buildContextProvider: Any?
    private var cancellables = Set<AnyCancellable>()

    /// 项目根路径
    private var currentProjectPath: String?
    private var currentWorkspaceURL: URL?
    private var cachedWorkspaceFolders: [[String: String]]?

    /// 是否已初始化
    public var isInitialized: Bool = false

    /// 正在初始化中，防止并发 projectOpened 重复执行
    private var isInitializingInProgress = false

    /// updateCache 防抖 Task（合并短时间内的多次 Combine 回调为一次通知广播）
    private var cacheDebounceTask: Task<Void, Never>?

    /// 当前项目是否为 Xcode 项目
    public var isXcodeProject: Bool = false

    /// 缓存的状态快照（供非主线程安全访问）
    public private(set) var cachedState: BridgeCachedState?
    public private(set) var latestEditorSnapshot: XcodeEditorContextSnapshot?

    /// buildServer.json 路径
    public var buildServerJSONPath: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.buildServerJSONPath } }

    /// active scheme
    public var activeScheme: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.activeScheme?.name } }

    /// active configuration
    public var activeConfiguration: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.activeConfiguration } }

    /// active destination
    public var activeDestination: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.activeDestination?.name } }
    public var activeDestinationQuery: String? { _buildContextProvider.flatMap { ($0 as? XcodeBuildContextProvider)?.activeDestination?.destinationQuery } }

    private init() {}

    // MARK: - XcodeContextProviding

    public var buildContextProvider: XcodeBuildContextProvider? {
        _buildContextProvider as? XcodeBuildContextProvider
    }

    public var cachedActiveScheme: String? { cachedState?.activeScheme }

    // MARK: - 注册 Build Context Provider

    public func registerBuildContextProvider(_ provider: XcodeBuildContextProvider) {
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
        provider.$resolutionProgress
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
        if Self.verbose {
                    Self.logger.info("\(Self.t)BuildContextProvider 已注册")
        }
        updateCache()
    }

    // MARK: - 项目打开

    public func projectOpened(at path: String) async {
        if currentProjectPath == path, isInitialized {
            updateCacheNow()
            return
        }
        // 防止多个并发的 Task 同时进入初始化流程
        guard !isInitializingInProgress else { return }
        isInitializingInProgress = true
        defer { isInitializingInProgress = false }

        currentProjectPath = path
        let provider = _buildContextProvider as? XcodeBuildContextProvider
        let inspection = await XcodeProjectBackgroundQuery.inspectProject(path: path, store: provider?.store)
        self.isXcodeProject = inspection.isXcodeProject
        currentWorkspaceURL = inspection.workspaceURL
        cachedWorkspaceFolders = Self.makeWorkspaceFolders(workspaceURL: inspection.workspaceURL)

        if Self.verbose {
                    Self.logger.info("\(Self.t)项目已打开: \(path, privacy: .public), 是 Xcode 项目: \(inspection.isXcodeProject)")
        }

        if inspection.isXcodeProject {
            await initializeXcodeBuildContext(projectPath: path, inspection: inspection)
        }

        isInitialized = true
        updateCacheNow()
    }

    public func projectClosed() {
        currentProjectPath = nil
        currentWorkspaceURL = nil
        cachedWorkspaceFolders = nil
        isXcodeProject = false
        isInitialized = false

        if let provider = _buildContextProvider as? XcodeBuildContextProvider {
            provider.invalidateAllContexts()
        }

        cachedState = nil
        latestEditorSnapshot = nil
        if Self.verbose {
                    Self.logger.info("\(Self.t)项目已关闭，build context 已失效")
        }
    }

    public func resyncBuildContext() async {
        guard let currentProjectPath, isXcodeProject else { return }
        guard let provider = _buildContextProvider as? XcodeBuildContextProvider else { return }

        if Self.verbose {
                    Self.logger.info("\(Self.t)手动触发 build context 重解析: \(currentProjectPath, privacy: .public)")
        }
        provider.invalidateAllContexts()
        let inspection = await XcodeProjectBackgroundQuery.inspectProject(path: currentProjectPath, store: provider.store)
        isXcodeProject = inspection.isXcodeProject
        currentWorkspaceURL = inspection.workspaceURL
        cachedWorkspaceFolders = Self.makeWorkspaceFolders(workspaceURL: inspection.workspaceURL)
        await initializeXcodeBuildContext(projectPath: currentProjectPath, inspection: inspection)
        isInitialized = true
        updateCacheNow()
    }

    // MARK: - Cache

    /// 防抖更新缓存（由 Combine 订阅回调触发）
    /// 短时间内的多次 @Published 变更（如 setActiveScheme 同时修改 scheme/config/destination）
    /// 会被合并为一次通知广播
    @MainActor
    private func updateCache() {
        cacheDebounceTask?.cancel()
        cacheDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms 防抖
            guard !Task.isCancelled else { return }
            updateCacheNow()
        }
    }

    /// 立即更新缓存并发送通知（用于 projectOpened / resync 等需要立即反映的场景）
    @MainActor
    private func updateCacheNow() {
        cacheDebounceTask?.cancel()
        cacheDebounceTask = nil

        let schemes = buildContextProvider?.currentWorkspace?.schemes.map(\.name) ?? []
        let configurations = buildContextProvider?.currentWorkspace?.projects.flatMap(\.buildConfigurations).map(\.name) ?? []
        let state = BridgeCachedState(
            workspaceFolders: makeWorkspaceFoldersInternal(),
            buildServerPath: buildServerJSONPath,
            activeScheme: activeScheme,
            activeConfiguration: activeConfiguration,
            activeDestination: activeDestination,
            buildContextStatus: buildContextProvider?.buildContextStatus.displayDescription ?? "Not Initialized",
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
        NotificationCenter.default.post(name: .lumiEditorProjectSnapshotDidChange, object: nil)
    }

    // MARK: - Build Context 初始化

    private func initializeXcodeBuildContext(
        projectPath path: String,
        inspection: XcodeProjectBackgroundQuery.ProjectInspection
    ) async {
        guard let provider = _buildContextProvider as? XcodeBuildContextProvider else {
            if Self.verbose {
                            Self.logger.warning("\(Self.t)BuildContextProvider 未注册，跳过初始化")
            }
            return
        }

        if inspection.validBuildServerConfig != nil, let workspaceURL = inspection.workspaceURL {
            await provider.openProject(at: workspaceURL)
            if Self.verbose {
                            Self.logger.info("\(Self.t)使用已有的 buildServer.json")
            }
            return
        }
        await provider.openProject(at: URL(fileURLWithPath: path))
    }

    private static func makeWorkspaceFolders(workspaceURL: URL?) -> [[String: String]]? {
        guard let workspaceURL else { return nil }
        let rootURL = workspaceURL.deletingLastPathComponent()
        return [["uri": "file://" + rootURL.path, "name": workspaceURL.deletingPathExtension().lastPathComponent]]
    }

    // MARK: - LSP 参数生成

    /// 为 sourcekit-lsp 生成 workspaceFolders 参数
    public func makeWorkspaceFolders() -> [[String: String]]? {
        cachedState?.workspaceFolders
    }

    private func makeWorkspaceFoldersInternal() -> [[String: String]]? {
        guard isXcodeProject else { return nil }
        return cachedWorkspaceFolders
    }

    public func getBuildServerPath() -> String? { cachedState?.buildServerPath }
    public var buildContextStatusDescription: String { cachedState?.buildContextStatus ?? "Not Initialized" }
    public var shouldHaveBuildContext: Bool { cachedState?.isXcodeProject ?? false }

    public func makeInitializationOptions() -> [String: Any]? {
        guard shouldHaveBuildContext else { return nil }
        var options: [String: Any] = [:]
        if let buildServerPath = getBuildServerPath() { options["buildServerPath"] = buildServerPath }
        if let scheme = cachedActiveScheme { options["scheme"] = scheme }
        if let configuration = cachedState?.activeConfiguration { options["configuration"] = configuration }
        if let destination = activeDestinationQuery { options["destination"] = destination }
        return options.isEmpty ? nil : options
    }

    public func makeEditorContextSnapshot(currentFileURL: URL? = nil) -> XcodeEditorContextSnapshot? {
        guard let cachedState else { return nil }
        let workspaceName = cachedState.workspaceName ?? URL(filePath: cachedState.projectPath ?? "").deletingPathExtension().lastPathComponent
        let buildableTargets = buildContextProvider?.activeScheme?.buildableTargets ?? []
        let preferredTarget = currentFileURL.flatMap { fileURL in
            buildContextProvider?.resolvePreferredTarget(for: fileURL)?.name
        }
        let matchedTargets = currentFileURL.flatMap { fileURL in
            buildContextProvider?.findTargetsForFile(fileURL: fileURL).map(\.name).sorted()
        } ?? []
        let isTargetMembershipResolved = buildContextProvider?.currentWorkspace?.projects.contains {
            $0.targets.contains { !$0.sourceFiles.isEmpty }
        } ?? false
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
            currentFileIsInTarget: !matchedTargets.isEmpty,
            isTargetMembershipResolved: isTargetMembershipResolved
        )
    }

    public func updateLatestEditorSnapshot(_ snapshot: XcodeEditorContextSnapshot?) {
        guard latestEditorSnapshot != snapshot else { return }
        latestEditorSnapshot = snapshot
        NotificationCenter.default.post(name: .lumiEditorProjectSnapshotDidChange, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 编辑器项目上下文变更通知
    public static let lumiEditorProjectContextDidChange = Notification.Name("lumiEditorProjectContextDidChange")
    /// 编辑器项目快照变更通知
    public static let lumiEditorProjectSnapshotDidChange = Notification.Name("lumiEditorProjectSnapshotDidChange")
}
