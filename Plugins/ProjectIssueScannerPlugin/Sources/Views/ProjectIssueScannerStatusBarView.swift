import SwiftUI
import LumiUI
import LumiCoreKit
import AppKit

// MARK: - ViewModel

/// 管理扫描状态的视图模型。
@MainActor
public final class ProjectIssueScannerViewModel: ObservableObject {
    /// Popover 列表最多展示的问题数
    private let displayLimit = 50

    /// 当前扫描状态
    @Published var state: ScannerState = .idle

    /// 当前展示的问题列表（最多 displayLimit 条）
    @Published var issues: [ProjectIssue] = []

    /// 未解决问题的总数（可能大于 issues.count）
    @Published var totalOpenCount: Int = 0

    /// 是否有更多问题未展示
    public var hasMore: Bool { totalOpenCount > issues.count }

    /// 最近一次持久化错误（用于向用户提示）
    @Published public var lastError: String?

    /// 触发手动扫描
    public func scan(projectPath: String) {
        let path = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            state = .idle
            issues = []
            totalOpenCount = 0
            return
        }

        Task {
            state = .scanning
            await IdleScannerService.shared.forceScan(projectPath: path)
            await reloadIssues(projectPath: path)
            state = .ready
        }
    }

    /// 从 Store 重新加载问题列表
    public func reloadIssues(projectPath: String) async {
        let path = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            issues = []
            totalOpenCount = 0
            return
        }

        // 总数：状态栏图标需要准确数字
        totalOpenCount = await ProjectIssueStore.shared.fetchOpen(projectPath: path).count
        // 列表：按严重程度排序，截断展示
        issues = await ProjectIssueStore.shared.fetchOpen(projectPath: path, limit: displayLimit)

        if state != .scanning {
            state = issues.isEmpty ? .idle : .ready
        }
    }

    /// 忽略指定问题
    public func dismiss(id: UUID, projectPath: String) async {
        do {
            try await ProjectIssueStore.shared.updateStatus(id: id, status: .dismissed)
        } catch {
            lastError = error.localizedDescription
        }
        await reloadIssues(projectPath: projectPath)
    }
}

// MARK: - Scanner State

public enum ScannerState: Equatable, Sendable {
    /// 无任务，无问题
    case idle
    /// 正在扫描
    case scanning
    /// 扫描完成，有 N 个未解决问题
    case ready
}

// MARK: - StatusBar View

/// 状态栏入口视图。
///
/// 显示当前未解决问题数量的图标，点击展开 Popover 查看详情。
public struct ProjectIssueScannerStatusBarView: View {
    @EnvironmentObject private var lumiCore: LumiCore
    @StateObject private var viewModel = ProjectIssueScannerViewModel()

    /// 模型偏好（从 UserDefaults 加载）
    @State private var modelPreference: ScannerModelPreference = ScannerModelPreference.load()

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public var body: some View {
        Group {
            if shouldShow {
                StatusBarHoverContainer(
                    detailView: ProjectIssueScannerPopover(
                        viewModel: viewModel,
                        projectPath: currentProjectPath,
                        modelPreference: $modelPreference
                    ),
                    popoverWidth: 480,
                    id: "project-issue-scanner"
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: iconName)
                            .font(.appMicroEmphasized)
                        if viewModel.totalOpenCount > 0 {
                            Text("\(viewModel.totalOpenCount)")
                                .font(.appMonoMicro)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            Task { await viewModel.reloadIssues(projectPath: currentProjectPath) }
        }
        .onChange(of: currentProjectPath) { _, _ in
            Task { await viewModel.reloadIssues(projectPath: currentProjectPath) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await viewModel.reloadIssues(projectPath: currentProjectPath) }
        }
        .onChange(of: modelPreference) { _, newPreference in
            newPreference.save()
            let preference = newPreference
            Task {
                await DeepIssueAnalyzer.shared.updateModelPreference(preference)
            }
        }
    }

    private var shouldShow: Bool {
        !currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var iconName: String {
        switch viewModel.state {
        case .scanning:
            return "arrow.triangle.2.circlepath"
        default:
            return "scope"
        }
    }
}

// MARK: - Popover

/// 问题列表弹窗视图。
public struct ProjectIssueScannerPopover: View {
    @ObservedObject var viewModel: ProjectIssueScannerViewModel
    public let projectPath: String
    @Binding var modelPreference: ScannerModelPreference

    private var primaryTextColor: Color {
        Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    private var secondaryTextColor: Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            modelPickerSection
            issuesList
            footer
        }
        .padding(14)
        .frame(minWidth: 440, minHeight: 300)
    }

    private var header: some View {
        HStack {
            Image(systemName: "scope")
                .foregroundColor(primaryTextColor)
            Text(LumiPluginLocalization.string("Project Issues", bundle: .module))
                .font(.headline)
                .foregroundColor(primaryTextColor)
            Spacer()
            Text(viewModel.hasMore
                 ? "\(viewModel.issues.count)/\(viewModel.totalOpenCount)"
                 : "\(viewModel.totalOpenCount)")
                .font(.caption)
                .foregroundColor(secondaryTextColor)
        }
    }

    private var modelPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: LumiPluginLocalization.string("模型选择", bundle: .module))
                .font(.caption)
                .foregroundColor(secondaryTextColor)

            ScannerModelPickerView(preference: $modelPreference)
        }
        .padding(10)
        .background(Color.adaptive(light: "F5F5F7", dark: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var issuesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if viewModel.issues.isEmpty {
                    emptyStateView
                } else {
                    ForEach(viewModel.issues) { issue in
                        IssueRow(issue: issue) {
                            Task { await viewModel.dismiss(id: issue.id, projectPath: projectPath) }
                        }
                    }

                    if viewModel.hasMore {
                        Text("Showing top \(viewModel.issues.count) of \(viewModel.totalOpenCount) issues, sorted by severity.")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if viewModel.state == .scanning {
            AppEmptyState(
                icon: "arrow.triangle.2.circlepath",
                title: LocalizedStringKey(LumiPluginLocalization.string("Scanning project issues...", bundle: .module))
            )
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            AppEmptyState(
                icon: "checkmark.circle",
                title: LocalizedStringKey(LumiPluginLocalization.string("No issues found", bundle: .module)),
                description: LocalizedStringKey(LumiPluginLocalization.string("Click Scan Now to check for potential issues.", bundle: .module)),
                actionTitle: LocalizedStringKey(LumiPluginLocalization.string("Scan Now", bundle: .module))
            ) {
                viewModel.scan(projectPath: projectPath)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        }
    }

    private var footer: some View {
        HStack {
            Text(statusText)
                .font(.caption)
                .foregroundColor(secondaryTextColor)
            Spacer()
            Button {
                viewModel.scan(projectPath: projectPath)
            } label: {
                Label(LumiPluginLocalization.string("Scan Now", bundle: .module), systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.state == .scanning)
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle:
            return LumiPluginLocalization.string("Idle", bundle: .module)
        case .scanning:
            return LumiPluginLocalization.string("Scanning", bundle: .module)
        case .ready:
            return LumiPluginLocalization.string("Ready", bundle: .module)
        }
    }
}

// MARK: - Issue Row

/// 单个问题的行视图。
private struct IssueRow: View {
    public let issue: ProjectIssue
    public let onDismiss: () -> Void

    private var primaryTextColor: Color {
        Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    private var secondaryTextColor: Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }

    private var rowBackgroundColor: Color {
        Color.adaptive(light: "F5F5F7", dark: "1C1C1E")
    }

    private var severityColor: Color {
        switch issue.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
                Text(issue.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(secondaryTextColor)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                Text(issue.filePath)
                    .lineLimit(1)
                if let line = issue.lineNumber {
                    Text(":\(line)")
                }
            }
            .font(.caption)
            .foregroundColor(secondaryTextColor)

            if let suggestion = issue.suggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(primaryTextColor.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(rowBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
