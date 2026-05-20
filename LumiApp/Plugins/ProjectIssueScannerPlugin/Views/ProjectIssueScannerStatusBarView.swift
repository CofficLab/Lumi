import SwiftUI
import LumiUI
import AppKit

// MARK: - ViewModel

/// 管理扫描状态的视图模型。
@MainActor
final class ProjectIssueScannerViewModel: ObservableObject {
    /// 当前扫描状态
    @Published var state: ScannerState = .idle

    /// 未解决的问题列表
    @Published var issues: [ProjectIssue] = []

    /// 触发手动扫描
    func scan(projectPath: String) {
        let path = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            state = .idle
            issues = []
            return
        }

        Task {
            state = .scanning
            await IdleScannerService.shared.forceScan(projectPath: path)
            await reloadIssues()
            state = .ready
        }
    }

    /// 从 Store 重新加载问题列表
    func reloadIssues() async {
        issues = await ProjectIssueStore.shared.fetchOpen()
        if state != .scanning {
            state = issues.isEmpty ? .idle : .ready
        }
    }

    /// 忽略指定问题
    func dismiss(id: UUID) async {
        await ProjectIssueStore.shared.updateStatus(id: id, status: .dismissed)
        await reloadIssues()
    }
}

// MARK: - Scanner State

enum ScannerState: Equatable, Sendable {
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
struct ProjectIssueScannerStatusBarView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @StateObject private var viewModel = ProjectIssueScannerViewModel()

    var body: some View {
        Group {
            if shouldShow {
                StatusBarHoverContainer(
                    detailView: ProjectIssueScannerPopover(viewModel: viewModel, projectPath: projectVM.currentProjectPath),
                    popoverWidth: 480,
                    id: "project-issue-scanner"
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: iconName)
                            .font(.system(size: 10))
                        if !viewModel.issues.isEmpty {
                            Text("\(viewModel.issues.count)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .monospacedDigit()
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            Task { await viewModel.reloadIssues() }
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            Task { await viewModel.reloadIssues() }
        }
        .onApplicationDidBecomeActive {
            Task { await viewModel.reloadIssues() }
        }
    }

    private var shouldShow: Bool {
        !projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
struct ProjectIssueScannerPopover: View {
    @ObservedObject var viewModel: ProjectIssueScannerViewModel
    let projectPath: String

    private var primaryTextColor: Color {
        Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    private var secondaryTextColor: Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
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
            Text(String(localized: "Project Issues", table: "ProjectIssueScanner"))
                .font(.headline)
                .foregroundColor(primaryTextColor)
            Spacer()
            Text("\(viewModel.issues.count)")
                .font(.caption)
                .foregroundColor(secondaryTextColor)
        }
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
                            Task { await viewModel.dismiss(id: issue.id) }
                        }
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
                title: LocalizedStringKey(String(localized: "Scanning project issues...", table: "ProjectIssueScanner", bundle: .main))
            )
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            AppEmptyState(
                icon: "checkmark.circle",
                title: LocalizedStringKey(String(localized: "No issues found", table: "ProjectIssueScanner", bundle: .main)),
                description: LocalizedStringKey(String(localized: "Click Scan Now to check for potential issues.", table: "ProjectIssueScanner", bundle: .main)),
                actionTitle: LocalizedStringKey(String(localized: "Scan Now", table: "ProjectIssueScanner", bundle: .main))
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
                Label(String(localized: "Scan Now", table: "ProjectIssueScanner"), systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.state == .scanning)
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle:
            return String(localized: "Idle", table: "ProjectIssueScanner")
        case .scanning:
            return String(localized: "Scanning", table: "ProjectIssueScanner")
        case .ready:
            return String(localized: "Ready", table: "ProjectIssueScanner")
        }
    }
}

// MARK: - Issue Row

/// 单个问题的行视图。
private struct IssueRow: View {
    let issue: ProjectIssue
    let onDismiss: () -> Void

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

    var body: some View {
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
