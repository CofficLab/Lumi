import Combine
import SwiftUI
import XcodeKit
import MagicKit
import os

// MARK: - XcodeProjectStatusBarViewModel

@MainActor
final class XcodeProjectStatusBarViewModel: ObservableObject, SuperLog {
    @Published var isXcodeProject = false
    @Published var activeScheme: String?
    @Published var schemes: [String] = []
    @Published var activeConfiguration: String?
    @Published var configurations: [String] = []
    @Published var activeDestination: String?
    @Published var buildContextStatus: XcodeBuildContextProvider.BuildContextStatus = .unknown
    @Published var buildContextStatusDescription = "Not Initialized"
    @Published var latestEditorSnapshot: XcodeEditorContextSnapshot?
    @Published var semanticReport: XcodeSemanticAvailability.Report = .init(reasons: [])
    @Published var isResyncingBuildContext = false
    @Published var indexingTask: ProgressTask?
    private var notificationCancellable: AnyCancellable?

    private var provider: XcodeBuildContextProvider?
    private var cancellables = Set<AnyCancellable>()

    init() {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t) 初始化开始")
        }
        setup()
    }

    private func setup() {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t) setup() 开始")
        }
        
        let bridge = XcodeProjectContextBridge.shared
        isXcodeProject = bridge.isXcodeProject
        activeScheme = bridge.cachedActiveScheme
        activeConfiguration = bridge.activeConfiguration
        activeDestination = bridge.activeDestination
        buildContextStatusDescription = bridge.buildContextStatusDescription
        latestEditorSnapshot = bridge.latestEditorSnapshot
        semanticReport = XcodeSemanticAvailability.inspectCurrentFileContext(uri: bridge.latestEditorSnapshot?.currentFilePath.flatMap { URL(filePath: $0).absoluteString }, contextProvider: bridge)
        indexingTask = LSPService.shared.progressProvider.primaryActiveTask

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t) 初始状态: isXcodeProject=\(self.isXcodeProject), activeScheme=\(self.activeScheme ?? "nil")")
        }

        guard let provider = bridge.buildContextProvider else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.warning("\(Self.t) buildContextProvider 为空")
            }
            return
        }
        self.provider = provider
        schemes = provider.currentWorkspace?.schemes.map(\.name) ?? []
        configurations = Array(Set(provider.currentWorkspace?.projects.flatMap(\.buildConfigurations).map(\.name) ?? [])).sorted()
        activeConfiguration = provider.activeConfiguration
        buildContextStatus = provider.buildContextStatus

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t) schemes 数量: \(self.schemes.count), configurations 数量: \(self.configurations.count)")
        }

        // 订阅 provider 的状态变化
        provider.$buildContextStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t) buildContextStatus 变化: \(status.displayDescription)")
                }
                self?.buildContextStatus = status
                self?.buildContextStatusDescription = status.displayDescription
            }
            .store(in: &cancellables)

        provider.$currentWorkspace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] workspace in
                guard let self else { return }
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t) workspace 变化: \(workspace?.name ?? "nil")")
                }
                self.isXcodeProject = workspace != nil
                self.schemes = workspace?.schemes.map(\.name) ?? []
                self.configurations = Array(Set(workspace?.projects.flatMap(\.buildConfigurations).map(\.name) ?? [])).sorted()
                self.activeScheme = workspace?.activeScheme?.name
                self.activeConfiguration = workspace?.activeScheme?.activeConfiguration
            }
            .store(in: &cancellables)

        provider.$activeScheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scheme in
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t) activeScheme 变化: \(scheme?.name ?? "nil")")
                }
                self?.activeScheme = scheme?.name
                self?.activeConfiguration = scheme?.activeConfiguration
            }
            .store(in: &cancellables)

        provider.$activeConfiguration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t) activeConfiguration 变化: \(configuration ?? "nil")")
                }
                self?.activeConfiguration = configuration
            }
            .store(in: &cancellables)

        provider.$activeDestination
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t) activeDestination 变化: \(destination?.name ?? "nil")")
                }
                self?.activeDestination = destination?.name
            }
            .store(in: &cancellables)

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
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t) 收到 projectContextDidChange 通知")
                }
                let bridge = XcodeProjectContextBridge.shared
                self?.activeDestination = bridge.activeDestination
                self?.latestEditorSnapshot = bridge.latestEditorSnapshot
                self?.semanticReport = XcodeSemanticAvailability.inspectCurrentFileContext(uri: bridge.latestEditorSnapshot?.currentFilePath.flatMap { URL(filePath: $0).absoluteString }, contextProvider: bridge)
            }

        NotificationCenter.default
            .publisher(for: .lumiEditorProjectSnapshotDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if XcodePluginLog.verbose {
                        XcodePluginLog.logger.info("\(Self.t) 收到 projectSnapshotDidChange 通知")
                }
                let bridge = XcodeProjectContextBridge.shared
                self?.latestEditorSnapshot = bridge.latestEditorSnapshot
                self?.semanticReport = XcodeSemanticAvailability.inspectCurrentFileContext(uri: bridge.latestEditorSnapshot?.currentFilePath.flatMap { URL(filePath: $0).absoluteString }, contextProvider: bridge)
            }
            .store(in: &cancellables)
        
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t) setup() 完成")
        }
    }

    func setActiveScheme(_ schemeName: String) {
        guard let provider, let scheme = provider.currentWorkspace?.schemes.first(where: { $0.name == schemeName }) else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.warning("\(Self.t) setActiveScheme 失败: 找不到 scheme \(schemeName)")
            }
            return
        }
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t) setActiveScheme: \(schemeName)")
        }
        Task {
            await provider.setActiveScheme(scheme)
        }
    }

    func setActiveConfiguration(_ configurationName: String) {
        guard let provider else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.warning("\(Self.t) setActiveConfiguration 失败: provider 为空")
            }
            return
        }
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t) setActiveConfiguration: \(configurationName)")
        }
        Task {
            await provider.setActiveConfiguration(configurationName)
        }
    }

    func resyncBuildContext() {
        guard !isResyncingBuildContext else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.warning("\(Self.t) resyncBuildContext 已在进行中，跳过")
            }
            return
        }
        isResyncingBuildContext = true
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t) 开始 resyncBuildContext")
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { 
                self.isResyncingBuildContext = false
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t) resyncBuildContext 完成")
                }
            }
            await XcodeProjectContextBridge.shared.resyncBuildContext()
            let bridge = XcodeProjectContextBridge.shared
            self.activeDestination = bridge.activeDestination
            self.latestEditorSnapshot = bridge.latestEditorSnapshot
            self.semanticReport = XcodeSemanticAvailability.inspectCurrentFileContext(
                uri: bridge.latestEditorSnapshot?.currentFilePath.flatMap { URL(filePath: $0).absoluteString },
                contextProvider: bridge
            )
        }
    }

    var isIndexing: Bool {
        indexingTask != nil
    }

    var semanticStatusText: String {
        if let indexingTask {
            if let percentage = indexingTask.percentage {
                return String(format: "Indexing %d%%", Int(percentage))
            }
            if let message = indexingTask.message, !message.isEmpty {
                return message
            }
            return indexingTask.title.isEmpty
                ? "Indexing..."
                : indexingTask.title
        }

        switch buildContextStatus {
        case .unknown:
            return "Not Detected"
        case .resolving:
            return "Resolving..."
        case .available:
            return "Ready"
        case .unavailable:
            return "Error"
        case .needsResync:
            return "Needs Sync"
        }
    }

    var semanticStatusDescription: String {
        if let indexingTask {
            var parts = ["Swift semantic indexing in progress"]
            if !indexingTask.title.isEmpty {
                parts.append(indexingTask.title)
            }
            if let message = indexingTask.message, !message.isEmpty {
                parts.append(message)
            }
            return parts.joined(separator: " · ")
        }
        return buildContextStatusDescription
    }

    var semanticStatusColor: Color {
        if isIndexing { return .blue }
        switch buildContextStatus {
        case .unknown: return .gray
        case .resolving: return .yellow
        case .available: return .green
        case .unavailable: return .red
        case .needsResync: return .orange
        }
    }
}
