import LibGit2Swift
import SuperLogKit
import SwiftUI
import LumiCoreKit
import LumiUI

/// Git 提交历史侧边栏视图
///
/// 参考 GitOK 的 CommitList + WorkingStateView 实现，显示当前项目的提交历史。
/// 列表顶部有一个 "当前状态" 入口，展示未提交的变更数量，点击后可以在 Detail 中查看工作区 diff。
/// 支持分页加载、切换项目时自动刷新。
public struct GitCommitHistorySidebarView: View, SuperLog {
    @EnvironmentObject var gitVM: AppGitVM
    @ObservedObject private var layoutState: LumiLayoutState

    public init() {
        _layoutState = ObservedObject(initialValue: LumiCore.layoutState ?? LumiLayoutState())
    }

    /// 项目状态
    private var projectState: LumiProjectState? {
        LumiCore.projectState
    }

    /// 当前项目路径
    private var currentProjectPath: String {
        projectState?.currentProject?.path ?? ""
    }

    /// 是否已选择项目
    private var isProjectSelected: Bool {
        projectState?.currentProject != nil
    }

    /// 提交列表数据
    @State private var commits: [GitCommitLog] = []

    /// 是否正在加载
    @State private var loading = false

    /// 是否还有更多数据
    @State private var hasMoreCommits = true

    /// 当前已加载的提交数量（分页偏移量）
    @State private var loadedCount: Int = 0

    /// 每页加载数量
    private let pageSize: Int = 30

    /// 是否已调度加载更多操作（防止快速连续触发）
    @State private var isLoadingMoreScheduled = false

    /// 当前刷新任务
    @State private var currentRefreshTask: Task<Void, Never>? = nil

    /// 当前加载批次。用于丢弃项目切换或刷新后的旧分页结果。
    @State private var loadGeneration: Int = 0

    /// 是否选中了某个 commit
    @State private var selectedCommitHash: String? = nil

    /// 未提交变更的文件数量
    @State private var uncommittedFileCount: Int = 0

    /// 是否正在加载未提交变更数量
    @State private var loadingUncommittedCount: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            // 提交列表
            if !commits.isEmpty || isProjectSelected {
                commitListView
            } else if loading {
                loadingView
            } else {
                noProjectView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            refresh("OnAppear")
        }
        .onChange(of: currentProjectPath) { _, _ in
            refresh("ProjectChanged")
        }
        .onApplicationDidBecomeActive {
            refresh("AppBecameActive")
        }
        .onCurrentProjectDidChange { _, _ in
            refresh("ProjectUpdated")
        }
    }

    // MARK: - Commit List View

    private var commitListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 顶部：工作状态入口
                workingStateView

                Divider()

                // Commit 列表
                ForEach(Array(commits.enumerated()), id: \.element.hash) { index, commit in
                    GitCommitListRow(
                        commit: commit,
                        isSelected: selectedCommitHash == commit.hash,
                        isUnpushed: gitVM.isCommitUnpushed(commit.hash),
                        action: {
                            selectedCommitHash = commit.hash
                            gitVM.selectCommit(hash: commit.hash)
                        }
                    )
                    .onAppear {
                        // 在最后几个 commit 出现时触发加载更多
                        let threshold = max(commits.count - 8, Int(Double(commits.count) * 0.8))

                        if index >= threshold && hasMoreCommits && !loading && !isLoadingMoreScheduled {
                            isLoadingMoreScheduled = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.isLoadingMoreScheduled = false
                                self.loadMoreCommits()
                            }
                        }
                    }
                }

                if loading && !commits.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }
                    .frame(height: 36)
                }
            }
        }
    }

    // MARK: - Working State View

    /// 工作状态入口，参考 GitOK 的 WorkingStateView
    /// 点击后清空 selectedCommitHash，Detail 面板会显示未提交的变更文件和 diff
    private var workingStateView: some View {
        let isWorkingStateSelected = selectedCommitHash == nil

        return HStack(spacing: 10) {
            // 图标
            if loadingUncommittedCount {
                ProgressView()
                    .controlSize(.small)
            } else if uncommittedFileCount == 0 {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.orange)
            }

            // 文本
            VStack(alignment: .leading, spacing: 2) {
                if uncommittedFileCount == 0 {
                    Text(LumiPluginLocalization.string("Clean working tree", bundle: .module))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                    Text(LumiPluginLocalization.string("All changes committed", bundle: .module))
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                } else {
                    Text(LumiPluginLocalization.string("Current status", bundle: .module))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                    Text(LumiPluginLocalization.string("Uncommitted files: \(uncommittedFileCount)", bundle: .module))
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            isWorkingStateSelected
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCommitHash = nil
            gitVM.selectCommit(hash: nil)
            // 确保侧边栏也选中这个标签
            if layoutState.activeViewContainerID != GitPlugin.info.id {
                layoutState.activateViewContainer(id: GitPlugin.info.id)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.regular)
            Text(LumiPluginLocalization.string("Loading...", bundle: .module))
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Project View

    private var noProjectView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(LumiPluginLocalization.string("Please select a project first", bundle: .module))
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Refresh

    /// 刷新提交列表
    /// - Parameter reason: 刷新原因，用于调试
    private func refresh(_ reason: String = "") {
        let path = currentProjectPath
        guard !path.isEmpty else {
            commits = []
            loading = false
            hasMoreCommits = true
            loadedCount = 0
            selectedCommitHash = nil
            uncommittedFileCount = 0
            gitVM.clearSelection()
            gitVM.clearUnpushedCommits()
            return
        }

        // 取消之前的刷新任务
        currentRefreshTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration

        loading = true
        loadedCount = 0
        hasMoreCommits = true
        selectedCommitHash = nil

        currentRefreshTask = Task {
            if Task.isCancelled { return }

            // 并行加载：commit 列表 + 未提交变更数量 + 未推送 commit
            async let commitsTask = GitService.shared.getLog(
                path: path,
                count: pageSize,
                branch: nil,
                file: nil
            )
            async let uncommittedTask: Void = loadUncommittedCount(path: path)

            // 在后台加载未推送 commit hashes
            let unpushedHashes = await Task.detached(priority: .userInitiated) {
                GitService.shared.getUnpushedCommitHashes(path: path)
            }.value

            do {
                let newCommits = try await commitsTask
                if Task.isCancelled { return }

                await MainActor.run {
                    guard self.loadGeneration == generation,
                          self.currentProjectPath == path else { return }
                    self.commits = newCommits
                    self.loading = false
                    self.loadedCount = newCommits.count
                    // 默认选中工作状态（selectedCommitHash = nil）
                    self.selectedCommitHash = nil
                    self.gitVM.selectCommit(hash: nil)
                    // 更新未推送 commit 状态
                    self.gitVM.updateUnpushedCommitHashes(unpushedHashes)
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run {
                    guard self.loadGeneration == generation,
                          self.currentProjectPath == path else { return }
                    self.commits = []
                    self.loading = false
                    // 即使加载 commit 失败，也尝试更新未推送状态
                    self.gitVM.updateUnpushedCommitHashes(unpushedHashes)
                }

                if GitPlugin.verbose {
                                    GitPlugin.logger.error("\(Self.t)刷新提交列表失败: \(error.localizedDescription)")
                }
            }

            // 加载未提交变更数量（不阻塞 commit 列表的显示）
            await uncommittedTask
        }
    }

    /// 加载未提交变更的文件数量
    private func loadUncommittedCount(path: String) async {
        await MainActor.run {
            loadingUncommittedCount = true
        }

        do {
            let files = try await GitService.shared.getUncommittedChanges(path: path)
            if Task.isCancelled { return }

            await MainActor.run {
                self.uncommittedFileCount = files.count
                self.loadingUncommittedCount = false
            }
        } catch {
            await MainActor.run {
                self.uncommittedFileCount = 0
                self.loadingUncommittedCount = false
            }
        }
    }

    // MARK: - Load More

    /// 加载更多提交记录
    private func loadMoreCommits() {
        let path = currentProjectPath
        guard !path.isEmpty, !loading, hasMoreCommits else { return }

        loading = true

        let skipCount = loadedCount
        let currentPage = pageSize
        let generation = loadGeneration

        Task.detached(priority: .userInitiated) {
            do {
                // 使用 git log --skip 获取后续提交
                let newCommits = try await GitService.shared.getLogWithSkip(
                    path: path,
                    count: currentPage,
                    skip: skipCount,
                    branch: nil
                )

                await MainActor.run {
                    guard self.loadGeneration == generation,
                          self.currentProjectPath == path else { return }
                    if !newCommits.isEmpty {
                        // 去重
                        let uniqueNewCommits = newCommits.filter { newCommit in
                            !self.commits.contains { existing in
                                existing.hash == newCommit.hash
                            }
                        }

                        if !uniqueNewCommits.isEmpty {
                            self.commits.append(contentsOf: uniqueNewCommits)
                        }
                        self.loadedCount = self.commits.count
                    } else {
                        self.hasMoreCommits = false
                    }
                    self.loading = false
                }
            } catch {
                await MainActor.run {
                    guard self.loadGeneration == generation,
                          self.currentProjectPath == path else { return }
                    self.loading = false
                }
                if GitPlugin.verbose {
                                    GitPlugin.logger.error("\(Self.t)加载更多提交失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Date Extension

extension Date {
    /// 生成相对时间字符串（如 "3分钟前"、"2小时前"）
    public var relativeTimeString: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return LumiPluginLocalization.string("Just now", bundle: .module)
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return LumiPluginLocalization.string("\(minutes) minutes ago", bundle: .module)
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return LumiPluginLocalization.string("\(hours) hours ago", bundle: .module)
        } else if interval < 2592000 {
            let days = Int(interval / 86400)
            return LumiPluginLocalization.string("\(days) days ago", bundle: .module)
        } else if interval < 31536000 {
            let months = Int(interval / 2592000)
            return LumiPluginLocalization.string("\(months) months ago", bundle: .module)
        } else {
            let years = Int(interval / 31536000)
            return LumiPluginLocalization.string("\(years) years ago", bundle: .module)
        }
    }
}

/// 日期格式化辅助
public enum DateParseHelper {
    /// 多种 ISO8601 格式尝试
    public static let formatHandlers: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }
    }()
}

// MARK: - GitService Extension

extension GitService {
    /// 获取带跳过的提交日志（分页加载用），使用 LibGit2Swift
    /// 已由 GitService.gitQueue 串行保护（调用 GitService.shared.getLogWithSkip）
    public func getLogWithSkip(path: String?, count: Int, skip: Int, branch: String?) async throws -> [GitCommitLog] {
        // 委托给 GitService 主文件中受 gitQueue 保护的方法
        return try await getLogWithSkip(path: path, count: count, skip: skip)
    }
}

// MARK: - Preview

#Preview {
    GitCommitHistorySidebarView()
        .inRootView()
        .frame(width: 250, height: 400)
}
