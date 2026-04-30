import Combine
import SwiftUI

/// Xcode 项目状态栏视图
struct XcodeProjectStatusBar: View {
    
    @StateObject private var viewModel = XcodeProjectStatusBarViewModel()
    
    var body: some View {
        Group {
            if viewModel.isXcodeProject {
                StatusBarHoverContainer(
                    detailView: XcodeProjectStatusDetailView(viewModel: viewModel),
                    popoverWidth: 440,
                    id: "lumi-xcode-project-status"
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)

                        schemeMenu
                        configurationMenu
                        destinationChip

                        buildContextIndicator
                    }
                    .padding(.horizontal, 4)
                    .frame(width: 400, alignment: .leading)
                }
            }
        }
    }
    
    // MARK: - Build Context 状态指示器
    
    private var buildContextIndicator: some View {
        HStack(spacing: 4) {
            if viewModel.isIndexing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            
            Text(statusText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .help(viewModel.semanticStatusDescription)
    }
    
    @ViewBuilder
    private var schemeMenu: some View {
        if !viewModel.schemes.isEmpty {
            Menu {
                ForEach(viewModel.schemes, id: \.self) { scheme in
                    Button(action: {
                        viewModel.setActiveScheme(scheme)
                    }) {
                        HStack {
                            Text(scheme)
                            if scheme == viewModel.activeScheme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text(viewModel.activeScheme ?? "Scheme")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
    
    @ViewBuilder
    private var configurationMenu: some View {
        if !viewModel.configurations.isEmpty {
            Menu {
                ForEach(viewModel.configurations, id: \.self) { configuration in
                    Button(action: {
                        viewModel.setActiveConfiguration(configuration)
                    }) {
                        HStack {
                            Text(configuration)
                            if configuration == viewModel.activeConfiguration {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 8))
                    Text(viewModel.activeConfiguration ?? "Config")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .cornerRadius(4)
            }
        }
    }

    @ViewBuilder
    private var destinationChip: some View {
        if let destination = viewModel.activeDestination, !destination.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "macwindow")
                    .font(.system(size: 8))
                Text(destination)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08))
            .cornerRadius(4)
            .help("当前编辑器语义上下文的目标平台")
        }
    }

    private var statusColor: Color {
        viewModel.semanticStatusColor
    }
    
    private var statusText: String {
        viewModel.semanticStatusText
    }
}

// MARK: - ViewModel

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
            .publisher(for: .lumiEditorXcodeSnapshotDidChange)
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

struct XcodeProjectStatusDetailView: View {
    @ObservedObject var viewModel: XcodeProjectStatusBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Xcode Context")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                buildStatusBadge
            }

            detailRow("Scheme", viewModel.activeScheme ?? "未选择")
            detailRow("Configuration", viewModel.activeConfiguration ?? "未选择")
            detailRow("Destination", viewModel.activeDestination ?? "未确定")
            detailRow("Build Context", viewModel.buildContextStatusDescription)

            HStack {
                Spacer()
                Button {
                    viewModel.resyncBuildContext()
                } label: {
                    if viewModel.isResyncingBuildContext {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("重新解析中")
                        }
                    } else {
                        Text("重新解析 Build Context")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
                .disabled(viewModel.isResyncingBuildContext)
            }

            Divider()

            if let snapshot = viewModel.latestEditorSnapshot {
                detailRow("Workspace", snapshot.workspaceName)
                detailRow("Current File", snapshot.currentFilePath ?? "未打开文件")
                detailRow("Preferred Target", snapshot.currentFileTarget ?? "未确定")
                detailRow(
                    "Matched Targets",
                    snapshot.currentFileMatchedTargets.isEmpty ? "无" : snapshot.currentFileMatchedTargets.joined(separator: ", ")
                )
                detailRow(
                    "Scheme Targets",
                    snapshot.activeSchemeBuildableTargets.isEmpty ? "无" : snapshot.activeSchemeBuildableTargets.joined(separator: ", ")
                )
                if !viewModel.semanticReport.reasons.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Semantic Availability")
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(viewModel.semanticReport.reasons) { reason in
                            reasonRow(reason)
                        }
                    }
                }
            } else {
                Text("当前没有可用的编辑器上下文快照。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var buildStatusBadge: some View {
        Text(viewModel.buildContextStatusDescription)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .cornerRadius(6)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12))
                .textSelection(.enabled)
        }
    }

    private func reasonRow(_ reason: XcodeSemanticAvailability.Reason) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color(for: reason.severity))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(reason.title)
                    .font(.system(size: 11, weight: .medium))
                Text(reason.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func color(for severity: XcodeSemanticAvailability.ReasonSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - 文件归属提示视图

/// 文件未绑定到任何 Target 的提示
/// 对应 Phase 8: "当前文件未绑定有效 target" 提示
struct XcodeFileNotInTargetWarning: View {
    let fileName: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("文件未在项目中注册")
                    .font(.headline)
            }
            
            Text("\"\(fileName)\" 未绑定到任何编译 target，跨文件语义导航可能不可用。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button("我知道了", action: onDismiss)
                    .buttonStyle(.bordered)
                
                Button("在 Xcode 中打开") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    VStack {
        XcodeProjectStatusBar()
            .padding()
        
        Divider()
        
        XcodeFileNotInTargetWarning(fileName: "MyFile.swift") { }
            .padding()
    }
}
