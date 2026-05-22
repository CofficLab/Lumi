import SwiftUI
import LumiUI
import AppKit

/// 为 UI 加载、同步并暴露 GitHub 生态缓存状态的视图模型。
@MainActor
final class GitHubKBStatusBarViewModel: ObservableObject {
    /// 状态栏和弹窗显示的当前同步状态。
    @Published var state: GitHubInsightSyncState = .idle

    /// 当前项目的缓存条目。
    @Published var entries: [GitHubInsightKBEntry] = []

    /// 当前项目的缓存项目画像。
    @Published var profile: GitHubInsightProjectProfile?

    private var loadTask: Task<Void, Never>?

    deinit {
        loadTask?.cancel()
    }

    /// 加载缓存数据，并在需要时同步项目缓存。
    func load(projectPath: String, force: Bool = false) {
        let path = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        loadTask?.cancel()

        guard !path.isEmpty else {
            state = .idle
            entries = []
            profile = nil
            loadTask = nil
            return
        }

        loadTask = Task { [weak self] in
            if !force {
                await self?.loadCache(projectPath: path)
                guard !Task.isCancelled else { return }
            }

            await MainActor.run { [weak self] in
                self?.state = .syncing
            }
            let newState = await GitHubInsightSyncService.shared.syncIfNeeded(projectPath: path, force: force)
            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                self?.state = newState
            }
            await self?.loadCache(projectPath: path)
        }
    }

    /// 仅加载持久化缓存，不触发 GitHub 发现。
    func loadCache(projectPath: String) async {
        guard let store = await GitHubInsightKnowledgeBaseManager.shared.loadStore(projectPath: projectPath) else {
            entries = []
            profile = nil
            if state != .syncing { state = .idle }
            return
        }
        entries = store.entries
        profile = store.profile
        if state != .syncing {
            state = .ready(count: store.entries.count)
        }
    }
}

/// 展示当前项目 GitHub 生态缓存状态的状态栏入口。
///
/// 视图会在出现、当前项目变化以及应用变为活跃时自动尝试同步缓存。
struct GitHubKBStatusBarView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @StateObject private var viewModel = GitHubKBStatusBarViewModel()

    var body: some View {
        Group {
            if shouldShow {
                StatusBarHoverContainer(
                    detailView: GitHubKBPopover(viewModel: viewModel, projectPath: projectVM.currentProjectPath),
                    popoverWidth: 720,
                    id: "github-insight-kb"
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: iconName)
                            .font(.appMicroEmphasized)
                        if let count = displayCount {
                            Text("\(count)")
                                .font(.appMonoMicro)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear { viewModel.load(projectPath: projectVM.currentProjectPath) }
        .onChange(of: projectVM.currentProjectPath) { _, newValue in
            viewModel.load(projectPath: newValue)
        }
        .onApplicationDidBecomeActive {
            viewModel.load(projectPath: projectVM.currentProjectPath)
        }
        .onReceive(NotificationCenter.default.publisher(for: .githubInsightDidSync)) { _ in
            Task { await viewModel.loadCache(projectPath: projectVM.currentProjectPath) }
        }
    }

    private var shouldShow: Bool {
        !projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && stateIsVisible
    }

    private var stateIsVisible: Bool {
        switch viewModel.state {
        case .idle:
            return !viewModel.entries.isEmpty
        default:
            return true
        }
    }

    private var iconName: String {
        switch viewModel.state {
        case .syncing: return "arrow.triangle.2.circlepath"
        case .rateLimited, .failed: return "exclamationmark.triangle"
        default: return "network"
        }
    }

    private var displayCount: Int? {
        switch viewModel.state {
        case .idle:
            return viewModel.entries.isEmpty ? nil : viewModel.entries.count
        case .syncing:
            return nil
        case .ready(let count):
            return count
        case .rateLimited, .failed:
            return nil
        }
    }
}

/// 展示缓存 GitHub 生态条目和手动同步控件的弹窗。
struct GitHubKBPopover: View {
    @ObservedObject var viewModel: GitHubKBStatusBarViewModel

    /// 用户触发强制同步时使用的项目路径。
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
            entriesList
            footer
        }
        .padding(14)
        .frame(minWidth: 620, minHeight: 360)
    }

    /// 显示知识库标题和项目画像摘要的头部区域。
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(primaryTextColor)
                Text(String(localized: "GitHub Ecosystem KB", table: "GitHubInsight"))
                    .font(.headline)
                    .foregroundColor(primaryTextColor)
                Spacer()
                Text("\(viewModel.entries.count)")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
            if let profile = viewModel.profile {
                Text(String(format: String(localized: "Profile: %@", table: "GitHubInsight"), profile.shortTitle))
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
    }

    /// 过滤后知识库条目的可滚动列表。
    private var entriesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if filteredEntries.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredEntries) { entry in
                        GitHubKBEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    /// 使用 LumiUI 统一空状态组件展示同步中或暂无数据状态。
    @ViewBuilder
    private var emptyStateView: some View {
        switch viewModel.state {
        case .syncing:
            AppEmptyState(
                icon: "arrow.triangle.2.circlepath",
                title: LocalizedStringKey(String(localized: "Syncing GitHub ecosystem references...", table: "GitHubInsight"))
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        default:
            AppEmptyState(
                icon: "magnifyingglass",
                title: LocalizedStringKey(String(localized: "No cached GitHub ecosystem references yet.", table: "GitHubInsight")),
                description: LocalizedStringKey(String(localized: "Click Sync Now to discover related GitHub repositories.", table: "GitHubInsight")),
                actionTitle: LocalizedStringKey(String(localized: "Sync Now", table: "GitHubInsight"))
            ) {
                viewModel.load(projectPath: projectPath, force: true)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        }
    }

    /// 显示同步状态和手动刷新按钮的底部区域。
    private var footer: some View {
        HStack {
            Text(statusText)
                .font(.caption)
                .foregroundColor(secondaryTextColor)
            Spacer()
            Button {
                viewModel.load(projectPath: projectPath, force: true)
            } label: {
                Label(String(localized: "Sync Now", table: "GitHubInsight"), systemImage: "arrow.clockwise")
            }
        }
    }

    /// 按相关性排序后的条目。
    private var filteredEntries: [GitHubInsightKBEntry] {
        viewModel.entries
            .sorted { $0.relevanceScore > $1.relevanceScore }
    }

    /// 显示在弹窗底部的可读同步状态。
    private var statusText: String {
        switch viewModel.state {
        case .idle:
            return String(localized: "Idle", table: "GitHubInsight")
        case .syncing:
            return String(localized: "Syncing", table: "GitHubInsight")
        case .ready(let count):
            return String(format: String(localized: "Ready: %lld entries", table: "GitHubInsight"), count)
        case .rateLimited:
            return String(localized: "GitHub rate limited", table: "GitHubInsight")
        case .failed(let message):
            return message
        }
    }
}

/// 单个缓存 GitHub 仓库参考的行视图。
private struct GitHubKBEntryRow: View {
    /// 当前行渲染的知识库条目。
    let entry: GitHubInsightKBEntry

    private var primaryTextColor: Color {
        Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    private var secondaryTextColor: Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }

    private var rowBackgroundColor: Color {
        Color.adaptive(light: "F5F5F7", dark: "1C1C1E")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(entry.fullName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                Spacer()
                Label("\(entry.stars)", systemImage: "star")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }

            if !entry.description.isEmpty {
                Text(entry.description)
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(2)
            }

            if let insight = entry.keyInsights.first {
                Text(insight)
                    .font(.caption)
                    .foregroundColor(primaryTextColor.opacity(0.8))
                    .lineLimit(2)
            }

            HStack {
                Text(entry.language ?? "Unknown")
                    .font(.caption2)
                    .foregroundColor(secondaryTextColor)
                Spacer()
                Button {
                    if let url = URL(string: entry.repoURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("GitHub", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.link)
            }
        }
        .padding(10)
        .background(rowBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
