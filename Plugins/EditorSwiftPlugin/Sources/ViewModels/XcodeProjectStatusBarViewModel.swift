import Combine
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

    @Published var isXcodeProject = false
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
    private var notificationCancellable: AnyCancellable?
    private var semanticRefreshTask: Task<Void, Never>?
    private var semanticLogPollingTask: Task<Void, Never>?

    private var provider: XcodeBuildContextProvider?
    private var providerSubscriptionsBound = false
    private var cancellables = Set<AnyCancellable>()

    deinit {
        semanticRefreshTask?.cancel()
        semanticLogPollingTask?.cancel()
    }

    private init() {
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

    private func syncBuildContextFromBridge() {
        let bridge = XcodeProjectContextBridge.shared
        isXcodeProject = bridge.isXcodeProject
        activeScheme = bridge.activeScheme ?? bridge.cachedActiveScheme
        activeConfiguration = bridge.activeConfiguration
        activeDestination = bridge.activeDestination
        buildContextStatusDescription = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(bridge.buildContextStatusDescription)
        latestEditorSnapshot = bridge.latestEditorSnapshot
        if let cached = bridge.cachedState {
            schemes = cached.schemes
            configurations = cached.configurations
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
        refreshSemanticIndexLogIfNeeded()
    }

    private func bindProviderSubscriptionsIfNeeded() {
        let bridge = XcodeProjectContextBridge.shared
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
            }
            .store(in: &cancellables)

        provider.$semanticIndexStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.semanticIndexStatus = status
                self?.handleSemanticIndexStatusChange()
            }
            .store(in: &cancellables)

        provider.$resolutionProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.resolutionProgress = progress
            }
            .store(in: &cancellables)

        provider.$currentWorkspace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] workspace in
                guard let self else { return }
                let bridge = XcodeProjectContextBridge.shared
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t) workspace 变化: \(workspace?.name ?? "nil")")
                }
                self.schemes = workspace?.schemes.map(\.name) ?? bridge.cachedState?.schemes ?? []
                self.configurations = Array(Set(workspace?.projects.flatMap(\.buildConfigurations).map(\.name) ?? [])).sorted()
                self.activeScheme = workspace?.activeScheme?.name
                self.activeConfiguration = workspace?.activeScheme?.activeConfiguration
                self.refreshSemanticIndexLogIfNeeded()
            }
            .store(in: &cancellables)

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
            }
            .store(in: &cancellables)

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
            .store(in: &cancellables)

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
            .store(in: &cancellables)

    }

    private func subscribeToCommonNotifications() {
        LSPService.shared.progressProvider.$activeTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.indexingTask = LSPService.shared.progressProvider.primaryActiveTask
            }
            .store(in: &cancellables)

        notificationCancellable = NotificationCenter.default
            .publisher(for: .lumiEditorProjectContextDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t) 收到 projectContextDidChange 通知")
                }
                self?.bindProviderSubscriptionsIfNeeded()
                self?.syncBuildContextFromBridge()
                self?.scheduleSemanticRefresh()
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
            await XcodeProjectContextBridge.shared.resyncBuildContext()
            await self?.finishResyncBuildContext()
        }
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
        isIndexing || isResolvingBuildContext || isSemanticIndexing
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
            startSemanticLogPolling()
        case .failed, .ready, .notStarted:
            stopSemanticLogPolling()
            refreshSemanticIndexLogIfNeeded()
        }
    }

    private func startSemanticLogPolling() {
        guard semanticLogPollingTask == nil else { return }
        semanticLogPollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshSemanticIndexLogIfNeeded()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
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
            semanticIndexLogExcerpt = readLogExcerpt(from: logURL)
        case .notStarted, .ready:
            semanticIndexLogExcerpt = nil
        }
    }

    private func semanticIndexLogURL() -> URL? {
        let workspacePath = provider?.currentWorkspace?.path.path
            ?? latestEditorSnapshot?.workspacePath
        guard let workspacePath, !workspacePath.isEmpty else { return nil }
        return EditorSwiftStorage.projectStoreDirectory(forWorkspacePath: workspacePath)
            .appendingPathComponent("semantic-index-build.log", isDirectory: false)
    }

    private func readLogExcerpt(from logURL: URL) -> String? {
        guard let content = try? String(contentsOf: logURL, encoding: .utf8),
              !content.isEmpty else {
            return nil
        }
        let lines = content
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .suffix(40)
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }
}
