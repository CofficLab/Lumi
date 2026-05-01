import Combine
import SwiftUI

// MARK: - XcodeProjectStatusBarViewModel

@MainActor
final class XcodeProjectStatusBarViewModel: ObservableObject {
    @Published var isXcodeProject = false
    @Published var activeScheme: String?
    @Published var schemes: [String] = []
    @Published var activeConfiguration: String?
    @Published var configurations: [String] = []
    @Published var activeDestination: String?
    @Published var buildContextStatus: XcodeBuildContextProvider.BuildContextStatus = .unknown
    @Published var buildContextStatusDescription = "未初始化"
    @Published var latestEditorSnapshot: XcodeEditorContextSnapshot?
    @Published var semanticReport: XcodeSemanticAvailability.Report = .init(reasons: [])
    @Published var isResyncingBuildContext = false
    @Published var indexingTask: ProgressTask?
    private var notificationCancellable: AnyCancellable?
    
    private var provider: XcodeBuildContextProvider?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setup()
    }
    
    private func setup() {
        let bridge = XcodeProjectContextBridge.shared
        isXcodeProject = bridge.isXcodeProject
        activeScheme = bridge.cachedActiveScheme
        activeConfiguration = bridge.activeConfiguration
        activeDestination = bridge.activeDestination
        buildContextStatusDescription = bridge.buildContextStatusDescription
        latestEditorSnapshot = bridge.latestEditorSnapshot
        semanticReport = XcodeSemanticAvailability.inspectCurrentFileContext(uri: bridge.latestEditorSnapshot?.currentFilePath.flatMap { URL(filePath: $0).absoluteString })
        indexingTask = LSPService.shared.progressProvider.primaryActiveTask
        
        guard let provider = bridge.buildContextProvider else { return }
        self.provider = provider
        schemes = provider.currentWorkspace?.schemes.map(\.name) ?? []
        configurations = Array(Set(provider.currentWorkspace?.projects.flatMap(\.buildConfigurations).map(\.name) ?? [])).sorted()
        activeConfiguration = provider.activeConfiguration
        buildContextStatus = provider.buildContextStatus
        
        // 订阅 provider 的状态变化
        provider.$buildContextStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.buildContextStatus = status
                self?.buildContextStatusDescription = status.displayDescription
            }
            .store(in: &cancellables)
        
        provider.$currentWorkspace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] workspace in
                guard let self else { return }
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
                self?.activeScheme = scheme?.name
                self?.activeConfiguration = scheme?.activeConfiguration
            }
            .store(in: &cancellables)

        provider.$activeConfiguration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                self?.activeConfiguration = configuration
            }
            .store(in: &cancellables)

        provider.$activeDestination
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
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
                let bridge = XcodeProjectContextBridge.shared
                self?.activeDestination = bridge.activeDestination
                self?.latestEditorSnapshot = bridge.latestEditorSnapshot
                self?.semanticReport = XcodeSemanticAvailability.inspectCurrentFileContext(uri: bridge.latestEditorSnapshot?.currentFilePath.flatMap { URL(filePath: $0).absoluteString })
            }

        NotificationCenter.default
            .publisher(for: .lumiEditorProjectSnapshotDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let bridge = XcodeProjectContextBridge.shared
                self?.latestEditorSnapshot = bridge.latestEditorSnapshot
                self?.semanticReport = XcodeSemanticAvailability.inspectCurrentFileContext(uri: bridge.latestEditorSnapshot?.currentFilePath.flatMap { URL(filePath: $0).absoluteString })
            }
            .store(in: &cancellables)
    }
    
    func setActiveScheme(_ schemeName: String) {
        guard let provider, let scheme = provider.currentWorkspace?.schemes.first(where: { $0.name == schemeName }) else { return }
        Task {
            await provider.setActiveScheme(scheme)
        }
    }

    func setActiveConfiguration(_ configurationName: String) {
        guard let provider else { return }
        Task {
            await provider.setActiveConfiguration(configurationName)
        }
    }

    func resyncBuildContext() {
        guard !isResyncingBuildContext else { return }
        isResyncingBuildContext = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isResyncingBuildContext = false }
            await XcodeProjectContextBridge.shared.resyncBuildContext()
            let bridge = XcodeProjectContextBridge.shared
            self.activeDestination = bridge.activeDestination
            self.latestEditorSnapshot = bridge.latestEditorSnapshot
            self.semanticReport = XcodeSemanticAvailability.inspectCurrentFileContext(
                uri: bridge.latestEditorSnapshot?.currentFilePath.flatMap { URL(filePath: $0).absoluteString }
            )
        }
    }

    var isIndexing: Bool {
        indexingTask != nil
    }

    var semanticStatusText: String {
        if let indexingTask {
            if let percentage = indexingTask.percentage {
                return "索引中 \(Int(percentage))%"
            }
            if let message = indexingTask.message, !message.isEmpty {
                return message
            }
            return indexingTask.title.isEmpty ? "索引中..." : indexingTask.title
        }

        switch buildContextStatus {
        case .unknown:
            return "未检测"
        case .resolving:
            return "解析中..."
        case .available:
            return "就绪"
        case .unavailable:
            return "错误"
        case .needsResync:
            return "需同步"
        }
    }

    var semanticStatusDescription: String {
        if let indexingTask {
            var parts = ["Swift 语义索引进行中"]
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
