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
    @Published var latestEditorSnapshot: XcodeEditorContextSnapshot?
    @Published var semanticReport: XcodeSemanticAvailability.Report = .init(reasons: [])
    @Published var isResyncingBuildContext = false
    @Published var indexingTask: ProgressTask?
    private var notificationCancellable: AnyCancellable?
    private var semanticRefreshTask: Task<Void, Never>?

    private var provider: XcodeBuildContextProvider?
    private var cancellables = Set<AnyCancellable>()

    deinit {
        semanticRefreshTask?.cancel()
    }

    private init() {
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t) 初始化开始（单例）")
            }
        }
        setup()
    }

    private func setup() {
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t) setup() 开始")
            }
        }
        
        let bridge = XcodeProjectContextBridge.shared
        isXcodeProject = bridge.isXcodeProject
        activeScheme = bridge.cachedActiveScheme
        activeConfiguration = bridge.activeConfiguration
        activeDestination = bridge.activeDestination
        buildContextStatusDescription = Self.localizedBuildContextStatusDescription(bridge.buildContextStatusDescription)
        latestEditorSnapshot = bridge.latestEditorSnapshot
        semanticReport = Self.makeSemanticReport(
            snapshot: bridge.latestEditorSnapshot,
            cachedState: bridge.cachedState,
            buildContextStatus: bridge.buildContextProvider?.buildContextStatus ?? .unknown
        )
        indexingTask = LSPService.shared.progressProvider.primaryActiveTask

        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t) 初始状态: isXcodeProject=\(self.isXcodeProject), activeScheme=\(self.activeScheme ?? "nil")")
            }
        }

        guard let provider = bridge.buildContextProvider else {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.warning("\(Self.t) buildContextProvider 为空")
                }
            }
            return
        }
        self.provider = provider
        schemes = provider.currentWorkspace?.schemes.map(\.name) ?? []
        configurations = Array(Set(provider.currentWorkspace?.projects.flatMap(\.buildConfigurations).map(\.name) ?? [])).sorted()
        activeConfiguration = provider.activeConfiguration
        buildContextStatus = provider.buildContextStatus

        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t) schemes 数量: \(self.schemes.count), configurations 数量: \(self.configurations.count)")
            }
        }

        // 订阅 provider 的状态变化
        provider.$buildContextStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if XcodePluginLog.verbose {
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("\(Self.t) buildContextStatus 变化: \(status.displayDescription)")
                    }
                }
                self?.buildContextStatus = status
                self?.buildContextStatusDescription = Self.localizedBuildContextStatusDescription(status)
            }
            .store(in: &cancellables)

        provider.$currentWorkspace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] workspace in
                guard let self else { return }
                if XcodePluginLog.verbose {
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("\(Self.t) workspace 变化: \(workspace?.name ?? "nil")")
                    }
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
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("\(Self.t) activeScheme 变化: \(scheme?.name ?? "nil")")
                    }
                }
                self?.activeScheme = scheme?.name
                self?.activeConfiguration = scheme?.activeConfiguration
            }
            .store(in: &cancellables)

        provider.$activeConfiguration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                if XcodePluginLog.verbose {
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("\(Self.t) activeConfiguration 变化: \(configuration ?? "nil")")
                    }
                }
                self?.activeConfiguration = configuration
            }
            .store(in: &cancellables)

        provider.$activeDestination
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                if XcodePluginLog.verbose {
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("\(Self.t) activeDestination 变化: \(destination?.name ?? "nil")")
                    }
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
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("\(Self.t) 收到 projectContextDidChange 通知")
                    }
                }
                self?.scheduleSemanticRefresh()
            }

        NotificationCenter.default
            .publisher(for: .lumiEditorProjectSnapshotDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if XcodePluginLog.verbose {
                        if XcodePluginLog.verbose {
                                                    XcodePluginLog.logger.info("\(Self.t) 收到 projectSnapshotDidChange 通知")
                        }
                }
                self?.scheduleSemanticRefresh()
            }
            .store(in: &cancellables)
        
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t) setup() 完成")
            }
        }
    }

    public func setActiveScheme(_ schemeName: String) {
        guard let provider, let scheme = provider.currentWorkspace?.schemes.first(where: { $0.name == schemeName }) else {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.warning("\(Self.t) setActiveScheme 失败: 找不到 scheme \(schemeName)")
                }
            }
            return
        }
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t) setActiveScheme: \(schemeName)")
            }
        }
        Task {
            await provider.setActiveScheme(scheme)
        }
    }

    public func setActiveConfiguration(_ configurationName: String) {
        guard let provider else {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.warning("\(Self.t) setActiveConfiguration 失败: provider 为空")
                }
            }
            return
        }
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t) setActiveConfiguration: \(configurationName)")
            }
        }
        Task {
            await provider.setActiveConfiguration(configurationName)
        }
    }

    public func resyncBuildContext() {
        guard !isResyncingBuildContext else {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.warning("\(Self.t) resyncBuildContext 已在进行中，跳过")
                }
            }
            return
        }
        isResyncingBuildContext = true
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t) 开始 resyncBuildContext")
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
        let bridge = XcodeProjectContextBridge.shared
        activeDestination = bridge.activeDestination
        latestEditorSnapshot = bridge.latestEditorSnapshot
        semanticReport = Self.makeSemanticReport(
            snapshot: bridge.latestEditorSnapshot,
            cachedState: bridge.cachedState,
            buildContextStatus: bridge.buildContextProvider?.buildContextStatus ?? .unknown
        )
    }

    private func finishResyncBuildContext() {
        refreshSemanticStateFromBridge()
        isResyncingBuildContext = false
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t) resyncBuildContext 完成")
            }
        }
    }

    private static func makeSemanticReport(
        snapshot: XcodeEditorContextSnapshot?,
        cachedState: BridgeCachedState?,
        buildContextStatus: XcodeBuildContextProvider.BuildContextStatus
    ) -> XcodeSemanticAvailability.Report {
        localizedSemanticReport(
            XcodeSemanticAvailability.inspectCurrentFileContext(
                snapshot: snapshot,
                cachedState: cachedState,
                buildContextStatus: buildContextStatus
            )
        )
    }

    private static func localizedSemanticReport(
        _ report: XcodeSemanticAvailability.Report
    ) -> XcodeSemanticAvailability.Report {
        XcodeSemanticAvailability.Report(
            reasons: report.reasons.map(localizedSemanticReason(_:))
        )
    }

    private static func localizedSemanticReason(
        _ reason: XcodeSemanticAvailability.Reason
    ) -> XcodeSemanticAvailability.Reason {
        XcodeSemanticAvailability.Reason(
            id: reason.id,
            severity: reason.severity,
            title: localizedSemanticReasonTitle(reason),
            message: localizedSemanticReasonMessage(reason)
        )
    }

    private static func localizedSemanticReasonTitle(
        _ reason: XcodeSemanticAvailability.Reason
    ) -> String {
        switch reason.id {
        case "server-not-started":
            return LumiPluginLocalization.string("LSP Not Initialized", bundle: .module)
        case "build-context-unavailable":
            return LumiPluginLocalization.string("Build Context Unavailable", bundle: .module)
        case "build-context-resync":
            return LumiPluginLocalization.string("Build Context Needs Sync", bundle: .module)
        case "file-not-in-target":
            return LumiPluginLocalization.string("File Not in Target", bundle: .module)
        case "scheme-excludes-targets":
            return LumiPluginLocalization.string("Scheme Does Not Cover File Target", bundle: .module)
        case "multiple-targets-resolved":
            return LumiPluginLocalization.string("Multi-Target File", bundle: .module)
        case "multiple-targets-ambiguous":
            return LumiPluginLocalization.string("Multi-Target Ambiguity", bundle: .module)
        case "destination-unknown":
            return LumiPluginLocalization.string("Destination Undetermined", bundle: .module)
        default:
            return reason.title
        }
    }

    private static func localizedSemanticReasonMessage(
        _ reason: XcodeSemanticAvailability.Reason
    ) -> String {
        switch reason.id {
        case "server-not-started":
            return LumiPluginLocalization.string("The current Xcode project context has not yet completed initialization.", bundle: .module)
        case "build-context-resync":
            return LumiPluginLocalization.string("The current build context has expired, workspace semantic results may be inaccurate.", bundle: .module)
        case "destination-unknown":
            return LumiPluginLocalization.string("The current target platform has not yet been resolved.", bundle: .module)
        case "build-context-unavailable":
            return localizedBuildContextStatusDescription(reason.message)
        case "file-not-in-target":
            let fileName = extractSingleQuotedValue(from: reason.message) ?? ""
            return String(
                format: LumiPluginLocalization.string("'%@' does not belong to any compilation target.", bundle: .module),
                fileName
            )
        case "scheme-excludes-targets":
            if let match = reason.message.firstMatch(of: #/Current scheme '(.+)' does not include (.+)\./#) {
                return String(
                    format: LumiPluginLocalization.string("Current scheme '%@' does not include %@.", bundle: .module),
                    String(match.1),
                    String(match.2)
                )
            }
            return reason.message
        case "multiple-targets-resolved":
            if let target = extractSingleQuotedValue(from: reason.message) {
                return String(
                    format: LumiPluginLocalization.string("Current file matches multiple targets, currently resolving with '%@'.", bundle: .module),
                    target
                )
            }
            return reason.message
        case "multiple-targets-ambiguous":
            if let match = reason.message.firstMatch(of: #/Current file belongs to (.+), but current scheme cannot uniquely determine semantic context\./#) {
                return String(
                    format: LumiPluginLocalization.string("Current file belongs to %@, but current scheme cannot uniquely determine semantic context.", bundle: .module),
                    String(match.1)
                )
            }
            return reason.message
        default:
            return reason.message
        }
    }

    private static func extractSingleQuotedValue(from text: String) -> String? {
        text.firstMatch(of: #/'([^']+)'/#).map { String($0.1) }
    }

    private static func localizedBuildContextStatusDescription(
        _ status: XcodeBuildContextProvider.BuildContextStatus
    ) -> String {
        switch status {
        case .unknown:
            return LumiPluginLocalization.string("Unknown", bundle: .module)
        case .resolving:
            return LumiPluginLocalization.string("Resolving build context...", bundle: .module)
        case .available(let config):
            return String(
                format: LumiPluginLocalization.string("Available (scheme: %@)", bundle: .module),
                config.scheme
            )
        case .unavailable(let reason):
            return String(
                format: LumiPluginLocalization.string("Unavailable: %@", bundle: .module),
                reason
            )
        case .needsResync:
            return LumiPluginLocalization.string("Needs resync", bundle: .module)
        }
    }

    private static func localizedBuildContextStatusDescription(_ text: String) -> String {
        if let match = text.firstMatch(of: #/Available \(scheme: (.+)\)/#) {
            return String(
                format: LumiPluginLocalization.string("Available (scheme: %@)", bundle: .module),
                String(match.1)
            )
        }
        if let match = text.firstMatch(of: #/Unavailable: (.+)/#) {
            return String(
                format: LumiPluginLocalization.string("Unavailable: %@", bundle: .module),
                String(match.1)
            )
        }
        switch text {
        case "Unknown":
            return LumiPluginLocalization.string("Unknown", bundle: .module)
        case "Resolving build context...":
            return LumiPluginLocalization.string("Resolving build context...", bundle: .module)
        case "Needs resync":
            return LumiPluginLocalization.string("Needs resync", bundle: .module)
        case "Not Initialized":
            return LumiPluginLocalization.string("Not Initialized", bundle: .module)
        default:
            return text
        }
    }

    private static func localizedIndexingTaskText(_ indexingTask: ProgressTask) -> String {
        if let percentage = indexingTask.percentage {
            return String(
                format: LumiPluginLocalization.string("Indexing %d%%", bundle: .module),
                Int(percentage)
            )
        }
        if let message = indexingTask.message, !message.isEmpty {
            return message
        }
        return indexingTask.title.isEmpty
            ? LumiPluginLocalization.string("Indexing...", bundle: .module)
            : indexingTask.title
    }

    private static func localizedSemanticStatusText(
        for buildContextStatus: XcodeBuildContextProvider.BuildContextStatus
    ) -> String {
        switch buildContextStatus {
        case .unknown:
            return LumiPluginLocalization.string("Not Detected", bundle: .module)
        case .resolving:
            return LumiPluginLocalization.string("Resolving...", bundle: .module)
        case .available:
            return LumiPluginLocalization.string("Ready", bundle: .module)
        case .unavailable:
            return LumiPluginLocalization.string("Error", bundle: .module)
        case .needsResync:
            return LumiPluginLocalization.string("Needs Sync", bundle: .module)
        }
    }

    public var isIndexing: Bool {
        indexingTask != nil
    }

    public var semanticStatusText: String {
        if let indexingTask {
            return Self.localizedIndexingTaskText(indexingTask)
        }

        return Self.localizedSemanticStatusText(for: buildContextStatus)
    }

    public var semanticStatusDescription: String {
        if let indexingTask {
            var parts = [LumiPluginLocalization.string("Swift semantic indexing in progress", bundle: .module)]
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

    public var semanticStatusColor: Color {
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
