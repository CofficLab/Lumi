import Combine
import AppKit
import EditorService
import SuperLogKit
import SwiftUI
import XcodeKit
import os
import LumiCoreKit

// MARK: - XcodeProjectStatusBarViewModel

@MainActor
public final class XcodeProjectStatusBarViewModel: ObservableObject, SuperLog {
    public static let shared = XcodeProjectStatusBarViewModel()

    private let session: XcodeProjectContextSession
    @Published var isXcodeProject = false
    @Published var isSwiftPackageProject = false
    @Published var spmPackageName: String?
    @Published var spmExecutableTarget: String?
    @Published var activeScheme: String?
    @Published var schemes: [String] = []
    @Published var activeConfiguration: String?
    @Published var configurations: [String] = []
    @Published var activeDestination: String?
    @Published var buildContextStatus: XcodeBuildContextProvider.BuildContextStatus = .unknown
    @Published var buildContextStatusDescription = LumiPluginLocalization.string("Not Initialized", bundle: .module)
    @Published var resolutionProgress: BuildContextResolutionProgress?
    @Published var semanticIndexStatus: XcodeSemanticIndexStatus = .notStarted
    @Published var latestEditorSnapshot: XcodeEditorContextSnapshot?
    @Published var semanticReport: XcodeSemanticAvailability.Report = .init(reasons: [])
    @Published var isResyncingBuildContext = false
    @Published var indexingTask: ProgressTask?
    @Published var semanticIndexLogExcerpt: String?
    @Published private(set) var capabilityLevel: SemanticCapabilityLevel = .syntaxOnly
    @Published private(set) var preflightIssues: [String] = []
    private var notificationCancellable: AnyCancellable?
    private var semanticRefreshTask: Task<Void, Never>?
    private var semanticLogPollingTask: Task<Void, Never>?
    private var capabilityRefreshTask: Task<Void, Never>?
    private var lastBoundProjectPath: String?
    private var storeProjectPath: String?
    private var isDetailPanelVisible = false
    private var unchangedLogPollCount = 0
    private var lastPolledLogExcerpt: String?

    private var provider: XcodeBuildContextProvider?
    private var providerSubscriptionsBound = false
    private var cancellables = Set<AnyCancellable>()
    private var providerCancellables = Set<AnyCancellable>()

    deinit {
        semanticRefreshTask?.cancel()
        semanticLogPollingTask?.cancel()
    }

    init(session: XcodeProjectContextSession = XcodeProjectContextSession()) {
        self.session = session
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t) 初始化开始（单例）")
            }
        }
        setup()
    }

    private func setup() {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t) setup() 开始")
            }
        }

        syncBuildContextFromBridge()
        subscribeToCommonNotifications()
        bindProviderSubscriptionsIfNeeded()

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t) setup() 完成, isXcodeProject=\(self.isXcodeProject), schemes=\(self.schemes.count)")
            }
        }
    }

    private var bridge: XcodeProjectContextBridge { session.bridge }

    public var buildContextProvider: XcodeBuildContextProvider? {
        bridge.buildContextProvider
    }

    public var activeProjectPath: String? {
        bridge.activeProjectPath
    }

    public var showsBuildToolbar: Bool {
        isXcodeProject || isSwiftPackageProject
    }

    private func syncBuildContextFromBridge() {
        let bridge = bridge
        if SwiftPluginLog.verbose {
            let providerActiveScheme = bridge.buildContextProvider?.currentWorkspace?.activeScheme?.name
            let providerWorkspaceName = bridge.buildContextProvider?.currentWorkspace?.name
            SwiftPluginLog.logger.info(
                "\(Self.t) syncBuildContextFromBridge enter activeProjectPath=\(bridge.activeProjectPath ?? "nil", privacy: .public) cached.projectPath=\(bridge.cachedState?.projectPath ?? "nil", privacy: .public) bridge.activeScheme=\(bridge.activeScheme ?? "nil", privacy: .public) bridge.cachedActiveScheme=\(bridge.cachedActiveScheme ?? "nil", privacy: .public) provider.activeScheme=\(providerActiveScheme ?? "nil", privacy: .public) provider.workspace=\(providerWorkspaceName ?? "nil", privacy: .public)"
            )
        }
        if !bridge.isXcodeProject {
            isXcodeProject = false
            resetProviderBindings()
            clearDisplayedProjectState()
            refreshSwiftPackageState()
            return
        }

        isSwiftPackageProject = false
        spmPackageName = nil
        spmExecutableTarget = nil

        let isCacheForActive = isBridgeCacheForActiveProject(bridge)
        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("\(Self.t) syncBuildContextFromBridge isCacheForActive=\(isCacheForActive)")
        }
        guard isCacheForActive else {
            isXcodeProject = bridge.isXcodeProject
            schemes = []
            configurations = []
            activeScheme = nil
            activeConfiguration = nil
            activeDestination = nil
            buildContextStatus = bridge.buildContextProvider?.buildContextStatus ?? .unknown
            buildContextStatusDescription = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(
                bridge.buildContextProvider?.buildContextStatus.displayDescription ?? "Not Initialized"
            )
            resolutionProgress = bridge.buildContextProvider?.resolutionProgress
            return
        }

        guard isBridgeMatchingStoreProject(bridge) else {
            clearSchemeDisplayState()
            isXcodeProject = bridge.isXcodeProject
            buildContextStatus = .resolving
            buildContextStatusDescription = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(
                XcodeBuildContextProvider.BuildContextStatus.resolving.displayDescription
            )
            return
        }

        isXcodeProject = bridge.isXcodeProject
        activeScheme = bridge.activeScheme ?? bridge.cachedActiveScheme
        activeConfiguration = bridge.activeConfiguration
        activeDestination = bridge.activeDestination
        buildContextStatusDescription = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(bridge.buildContextStatusDescription)
        latestEditorSnapshot = bridge.latestEditorSnapshot
        if let cached = bridge.cachedState {
            schemes = cached.schemes
            configurations = cached.configurations
        } else {
            schemes = []
            configurations = []
            activeScheme = nil
            activeConfiguration = nil
            activeDestination = nil
        }
        buildContextStatus = bridge.buildContextProvider?.buildContextStatus ?? .unknown
        resolutionProgress = bridge.buildContextProvider?.resolutionProgress
        semanticIndexStatus = bridge.buildContextProvider?.semanticIndexStatus ?? .notStarted
        semanticReport = XcodeProjectStatusPresentation.makeSemanticReport(
            snapshot: bridge.latestEditorSnapshot,
            cachedState: bridge.cachedState,
            buildContextStatus: bridge.buildContextProvider?.buildContextStatus ?? .unknown
        )
        indexingTask = LSPService.shared.progressProvider.primaryActiveTask
        scheduleCapabilityRefresh()
    }

    public func refreshPreflight(force: Bool = false) {
        let preflight = XcodeBuildServerPreflightCache.runPreflight(forceRefresh: force)
        preflightIssues = preflight.issues
        scheduleCapabilityRefresh()
    }

    func detailPanelDidAppear() {
        isDetailPanelVisible = true
        refreshPreflight(force: true)
        startSemanticLogPolling()
    }

    func detailPanelDidDisappear() {
        isDetailPanelVisible = false
        stopSemanticLogPolling()
    }

    private func scheduleCapabilityRefresh() {
        capabilityRefreshTask?.cancel()
        capabilityRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            self?.refreshCapabilityLevel()
        }
    }

    private func refreshCapabilityLevel() {
        let bridge = bridge
        let workspacePath = bridge.activeProjectPath
        let store = bridge.buildContextProvider?.store
        let compileURL = workspacePath.flatMap { store?.compileDatabaseURL(forWorkspace: $0) }
        let manifest = workspacePath.flatMap { store?.loadManifest(forWorkspace: $0) }
        let preflight = XcodeBuildServerPreflightCache.runPreflight()
        preflightIssues = preflight.issues
        capabilityLevel = SemanticCapabilityLevelResolver.resolve(
            isXcodeProject: bridge.isXcodeProject,
            buildServerAvailable: bridge.buildServerJSONPath != nil || preflight.xcodeBuildServerPath != nil,
            semanticIndexStatus: semanticIndexStatus,
            manifest: manifest,
            compileDatabaseURL: compileURL,
            scheme: activeScheme
        )
    }

    public var capabilityLevelDescription: String {
        XcodeProjectStatusPresentation.localizedCapabilityLevelDescription(capabilityLevel)
    }

    public func exportDiagnostics() {
        guard let workspacePath = currentWorkspacePath(),
              let store = bridge.buildContextProvider?.store else {
            return
        }
        let package = SemanticIndexDiagnosticsExporter.makePackage(
            workspacePath: workspacePath,
            store: store,
            preflight: XcodeBuildServerPreflightCache.runPreflight(forceRefresh: true),
            semanticIndexStatus: semanticIndexStatus,
            capabilityLevel: capabilityLevel
        )
        if let url = SemanticIndexDiagnosticsExporter.exportToDownloads(package) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func resetDisplayedStateForTesting() {
        clearDisplayedProjectState()
    }

    func refreshSwiftPackageStateForTesting(projectPath: String) {
        isXcodeProject = false
        let projectURL = URL(fileURLWithPath: projectPath, isDirectory: true)
        guard let packageRoot = SwiftPackageManifestParser.findPackageDirectory(for: projectURL)
            ?? (FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path) ? projectURL : nil)
        else {
            isSwiftPackageProject = false
            return
        }
        let executables = SwiftPackageManifestParser.executableTargetNames(packageRoot: packageRoot)
        isSwiftPackageProject = !executables.isEmpty
        spmPackageName = packageRoot.lastPathComponent
        spmExecutableTarget = executables.count == 1 ? executables[0] : nil
    }

    private func clearDisplayedProjectState() {
        schemes = []
        configurations = []
        activeScheme = nil
        activeConfiguration = nil
        activeDestination = nil
        isSwiftPackageProject = false
        spmPackageName = nil
        spmExecutableTarget = nil
        buildContextStatus = .unknown
        buildContextStatusDescription = LumiPluginLocalization.string("Not Initialized", bundle: .module)
        resolutionProgress = nil
        semanticIndexStatus = .notStarted
        latestEditorSnapshot = nil
        semanticReport = XcodeSemanticAvailability.Report(reasons: [])
        semanticIndexLogExcerpt = nil
        indexingTask = LSPService.shared.progressProvider.primaryActiveTask
    }

    private func refreshSwiftPackageState() {
        guard let projectPath = bridge.activeProjectPath, !projectPath.isEmpty else {
            isSwiftPackageProject = false
            spmPackageName = nil
            spmExecutableTarget = nil
            return
        }

        let projectURL = URL(fileURLWithPath: projectPath, isDirectory: true)
        guard let packageRoot = SwiftPackageManifestParser.findPackageDirectory(for: projectURL)
            ?? (FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path) ? projectURL : nil)
        else {
            isSwiftPackageProject = false
            spmPackageName = nil
            spmExecutableTarget = nil
            return
        }

        let executables = SwiftPackageManifestParser.executableTargetNames(packageRoot: packageRoot)
        isSwiftPackageProject = !executables.isEmpty
        spmPackageName = packageRoot.lastPathComponent
        spmExecutableTarget = executables.count == 1 ? executables[0] : nil
    }

    private func resetProviderBindings() {
        providerCancellables.removeAll()
        providerSubscriptionsBound = false
        provider = nil
    }

    private func bindProviderSubscriptionsIfNeeded() {
        let bridge = bridge
        guard !providerSubscriptionsBound, let provider = bridge.buildContextProvider else {
            if SwiftPluginLog.verbose, bridge.buildContextProvider == nil {
                SwiftPluginLog.logger.warning("\(Self.t) buildContextProvider 为空，等待后续绑定")
            }
            return
        }
        self.provider = provider
        providerSubscriptionsBound = true

        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("\(Self.t) 绑定 provider, schemes 数量: \(provider.currentWorkspace?.schemes.count ?? 0)")
        }

        provider.$buildContextStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                                            SwiftPluginLog.logger.info("\(Self.t) buildContextStatus 变化: \(status.displayDescription)")
                    }
                }
                self?.buildContextStatus = status
                self?.buildContextStatusDescription = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(status)
                if case .resolving = status {
                    // Keep progress updates while resolving.
                } else {
                    self?.resolutionProgress = nil
                }
                self?.scheduleCapabilityRefresh()
            }
            .store(in: &providerCancellables)

        provider.$semanticIndexStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.semanticIndexStatus = status
                self?.handleSemanticIndexStatusChange()
                self?.scheduleCapabilityRefresh()
                if case .ready = status {
                    SemanticIndexPreloadCoordinator.scheduleResume()
                } else if case .failed = status {
                    SemanticIndexPreloadCoordinator.scheduleResume()
                }
            }
            .store(in: &providerCancellables)

        provider.$resolutionProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.resolutionProgress = progress
            }
            .store(in: &providerCancellables)

        provider.$currentWorkspace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] workspace in
                guard let self else { return }
                guard self.shouldApplyProviderWorkspace(workspace) else { return }
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t) workspace 变化: \(workspace?.name ?? "nil")")
                }
                if let workspace {
                    self.schemes = workspace.schemes.map(\.name)
                    self.configurations = Array(Set(workspace.projects.flatMap(\.buildConfigurations).map(\.name))).sorted()
                    self.activeScheme = workspace.activeScheme?.name
                    self.activeConfiguration = workspace.activeScheme?.activeConfiguration
                } else {
                    self.schemes = []
                    self.configurations = []
                    self.activeScheme = nil
                    self.activeConfiguration = nil
                }
                self.refreshSemanticIndexLogIfNeeded()
            }
            .store(in: &providerCancellables)

        provider.$activeScheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scheme in
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                                            SwiftPluginLog.logger.info("\(Self.t) activeScheme 变化: \(scheme?.name ?? "nil")")
                    }
                }
                self?.activeScheme = scheme?.name
                self?.activeConfiguration = scheme?.activeConfiguration
                self?.scheduleCapabilityRefresh()
            }
            .store(in: &providerCancellables)

        provider.$activeConfiguration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                                            SwiftPluginLog.logger.info("\(Self.t) activeConfiguration 变化: \(configuration ?? "nil")")
                    }
                }
                self?.activeConfiguration = configuration
            }
            .store(in: &providerCancellables)

        provider.$activeDestination
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                                            SwiftPluginLog.logger.info("\(Self.t) activeDestination 变化: \(destination?.name ?? "nil")")
                    }
                }
                self?.activeDestination = destination?.name
            }
            .store(in: &providerCancellables)

    }

    private func subscribeToCommonNotifications() {
        LSPService.shared.progressProvider.$activeTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.indexingTask = LSPService.shared.progressProvider.primaryActiveTask
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .currentProjectPathDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let path = notification.userInfo?["path"] as? String ?? ""
                self.storeProjectPath = path
                if path != (self.bridge.activeProjectPath ?? "") {
                    self.clearSchemeDisplayState()
                    self.buildContextStatus = .resolving
                    self.buildContextStatusDescription = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(
                        XcodeBuildContextProvider.BuildContextStatus.resolving.displayDescription
                    )
                }
            }
            .store(in: &cancellables)

        notificationCancellable = NotificationCenter.default
            .publisher(for: .lumiEditorProjectContextDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t) 收到 projectContextDidChange 通知")
                }
                guard let self else { return }
                let activePath = self.bridge.activeProjectPath
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info(
                        "\(Self.t) projectContextDidChange activeProjectPath=\(activePath ?? "nil", privacy: .public) lastBoundProjectPath=\(self.lastBoundProjectPath ?? "nil", privacy: .public)"
                    )
                }
                if self.lastBoundProjectPath != activePath {
                    self.resetProviderBindings()
                    self.lastBoundProjectPath = activePath
                    self.bindProviderSubscriptionsIfNeeded()
                }
                self.syncBuildContextFromBridge()
                self.scheduleSemanticRefresh()
            }

        NotificationCenter.default
            .publisher(for: .lumiEditorProjectSnapshotDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t) 收到 projectSnapshotDidChange 通知")
                }
                self?.scheduleSemanticRefresh()
            }
            .store(in: &cancellables)
    }

    public func setActiveScheme(_ schemeName: String) {
        guard let provider, let scheme = provider.currentWorkspace?.schemes.first(where: { $0.name == schemeName }) else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.warning("\(Self.t) setActiveScheme 失败: 找不到 scheme \(schemeName)")
                }
            }
            return
        }
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t) setActiveScheme: \(schemeName)")
            }
        }
        Task {
            await provider.setActiveScheme(scheme)
        }
    }

    public func setActiveConfiguration(_ configurationName: String) {
        guard let provider else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.warning("\(Self.t) setActiveConfiguration 失败: provider 为空")
                }
            }
            return
        }
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t) setActiveConfiguration: \(configurationName)")
            }
        }
        Task {
            await provider.setActiveConfiguration(configurationName)
        }
    }

    public func resyncBuildContext() {
        guard !isResyncingBuildContext else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.warning("\(Self.t) resyncBuildContext 已在进行中，跳过")
                }
            }
            return
        }
        isResyncingBuildContext = true
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t) 开始 resyncBuildContext")
            }
        }
        Task.detached { [weak self] in
            await self?.session.resyncBuildContext()
            await self?.finishResyncBuildContext()
        }
    }

    public func openCacheDirectory() {
        guard let directory = currentWorkspaceStoreDirectory() else { return }
        NSWorkspace.shared.open(directory)
    }

    public func reindexNow() {
        guard let workspacePath = currentWorkspacePath() else { return }
        EditorSwiftStorage.purgeBuildCaches(forWorkspacePath: workspacePath)
        semanticIndexLogExcerpt = nil
        resyncBuildContext()
    }

    public func clearIndexData() {
        guard let workspacePath = currentWorkspacePath() else { return }
        EditorSwiftStorage.clearWorkspaceData(forWorkspacePath: workspacePath)
        semanticIndexLogExcerpt = nil
        resyncBuildContext()
    }

    private func clearSchemeDisplayState() {
        schemes = []
        configurations = []
        activeScheme = nil
        activeConfiguration = nil
        activeDestination = nil
    }

    private func isBridgeCacheForActiveProject(_ bridge: XcodeProjectContextBridge) -> Bool {
        guard let activePath = bridge.activeProjectPath else { return false }
        guard let cachedPath = bridge.cachedState?.projectPath else { return false }
        return URL(fileURLWithPath: cachedPath).standardizedFileURL.path
            == URL(fileURLWithPath: activePath).standardizedFileURL.path
    }

    private func isBridgeMatchingStoreProject(_ bridge: XcodeProjectContextBridge) -> Bool {
        guard let storePath = storeProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !storePath.isEmpty else {
            return true
        }
        guard let activePath = bridge.activeProjectPath else { return false }
        return URL(fileURLWithPath: activePath).standardizedFileURL.path
            == URL(fileURLWithPath: storePath).standardizedFileURL.path
    }

    private func shouldApplyProviderWorkspace(_ workspace: XcodeWorkspaceContext?) -> Bool {
        let bridge = bridge
        guard let activePath = bridge.activeProjectPath else { return workspace == nil }
        guard let workspace else { return true }
        let workspaceRoot = workspace.path.deletingLastPathComponent().standardizedFileURL.path
        let activeRoot = URL(fileURLWithPath: activePath).standardizedFileURL.path
        return workspaceRoot == activeRoot
            || workspaceRoot.hasPrefix(activeRoot + "/")
            || activeRoot.hasPrefix(workspaceRoot + "/")
    }

    private func scheduleSemanticRefresh() {
        semanticRefreshTask?.cancel()
        semanticRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            self?.refreshSemanticStateFromBridge()
        }
    }

    private func refreshSemanticStateFromBridge() {
        syncBuildContextFromBridge()
    }

    private func finishResyncBuildContext() {
        refreshSemanticStateFromBridge()
        isResyncingBuildContext = false
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t) resyncBuildContext 完成")
            }
        }
    }

    public var isResolvingBuildContext: Bool {
        if case .resolving = buildContextStatus { return true }
        return false
    }

    public var isSemanticIndexing: Bool {
        if case .indexing = semanticIndexStatus { return true }
        return false
    }

    public var isIndexing: Bool {
        indexingTask != nil
    }

    public var showsActivityIndicator: Bool {
        // Toolbar activity should only reflect Xcode context lifecycle.
        isResolvingBuildContext || isSemanticIndexing
    }

    public func semanticStatusText(now: Date = Date()) -> String {
        XcodeProjectStatusPresentation.semanticStatusText(
            indexingTask: indexingTask,
            buildContextStatus: buildContextStatus,
            semanticIndexStatus: semanticIndexStatus,
            resolutionProgress: resolutionProgress,
            now: now
        )
    }

    public var semanticStatusDescription: String {
        XcodeProjectStatusPresentation.semanticStatusDescription(
            indexingTask: indexingTask,
            buildContextStatusDescription: buildContextStatusDescription,
            semanticIndexStatus: semanticIndexStatus,
            resolutionProgress: resolutionProgress
        )
    }

    public var semanticIndexFailureReason: String? {
        guard case .failed(let reason) = semanticIndexStatus else { return nil }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var schemePlaceholderText: String {
        XcodeProjectStatusPresentation.resolvingSchemePlaceholder(
            activeScheme: activeScheme,
            resolutionProgress: resolutionProgress
        )
    }

    public var resolutionProgressDetailText: String? {
        guard let resolutionProgress else { return nil }
        return XcodeProjectStatusPresentation.localizedResolutionProgressDetail(resolutionProgress)
    }

    public var semanticStatusColor: Color {
        let appearance = XcodeProjectStatusPresentation.semanticStatusAppearance(
            isIndexing: isIndexing,
            isResolving: isResolvingBuildContext,
            isSemanticIndexing: isSemanticIndexing,
            buildContextStatus: buildContextStatus,
            semanticIndexStatus: semanticIndexStatus
        )
        return XcodeProjectStatusPresentation.color(for: appearance)
    }

    private func handleSemanticIndexStatusChange() {
        switch semanticIndexStatus {
        case .indexing:
            if isDetailPanelVisible {
                startSemanticLogPolling()
            }
        case .failed, .ready, .notStarted:
            stopSemanticLogPolling()
            if isDetailPanelVisible {
                refreshSemanticIndexLogIfNeeded()
            } else {
                semanticIndexLogExcerpt = nil
            }
        }
    }

    private func startSemanticLogPolling() {
        guard isDetailPanelVisible else { return }
        guard semanticLogPollingTask == nil else { return }
        unchangedLogPollCount = 0
        semanticLogPollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isDetailPanelVisible else { break }
                self.refreshSemanticIndexLogIfNeeded()
                let interval: UInt64
                if self.unchangedLogPollCount >= 3 {
                    interval = 5_000_000_000
                } else {
                    interval = 2_000_000_000
                }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func stopSemanticLogPolling() {
        semanticLogPollingTask?.cancel()
        semanticLogPollingTask = nil
    }

    private func refreshSemanticIndexLogIfNeeded() {
        switch semanticIndexStatus {
        case .indexing, .failed:
            guard let logURL = semanticIndexLogURL() else {
                semanticIndexLogExcerpt = nil
                return
            }
            let excerpt = SemanticIndexLogReader.tailExcerpt(at: logURL)
            if excerpt == lastPolledLogExcerpt {
                unchangedLogPollCount += 1
            } else {
                unchangedLogPollCount = 0
                lastPolledLogExcerpt = excerpt
            }
            semanticIndexLogExcerpt = excerpt
        case .notStarted, .ready:
            semanticIndexLogExcerpt = nil
            lastPolledLogExcerpt = nil
            unchangedLogPollCount = 0
        }
    }

    private func semanticIndexLogURL() -> URL? {
        let workspacePath = currentWorkspacePath()
        guard let workspacePath, !workspacePath.isEmpty else { return nil }
        return EditorSwiftStorage.projectStoreDirectory(forWorkspacePath: workspacePath)
            .appendingPathComponent("semantic-index-build.log", isDirectory: false)
    }

    private func currentWorkspacePath() -> String? {
        provider?.currentWorkspace?.path.path ?? latestEditorSnapshot?.workspacePath
    }

    private func currentWorkspaceStoreDirectory() -> URL? {
        guard let workspacePath = currentWorkspacePath(), !workspacePath.isEmpty else {
            return nil
        }
        return EditorSwiftStorage.projectStoreDirectory(forWorkspacePath: workspacePath)
    }
}
