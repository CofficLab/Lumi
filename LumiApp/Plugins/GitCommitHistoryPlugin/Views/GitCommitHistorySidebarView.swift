import SwiftUI
import MagicKit

/// Git 提交历史侧边栏视图
///
/// 参考 GitOK 的 CommitList 实现，显示当前项目的提交历史。
/// 支持分页加载、切换项目时自动刷新。
struct GitCommitHistorySidebarView: View {
    @EnvironmentObject var projectVM: ProjectVM

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

    /// 是否选中了某个 commit
    @State private var selectedCommitHash: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 提交列表
            if !commits.isEmpty {
                commitListView
            } else if loading {
                loadingView
            } else if projectVM.isProjectSelected {
                emptyView
            } else {
                noProjectView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            refresh("OnAppear")
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
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
                ForEach(Array(commits.enumerated()), id: \.element.hash) { index, commit in
                    GitCommitRow(
                        commit: commit,
                        isSelected: selectedCommitHash == commit.hash
                    )
                    .onTapGesture {
                        selectedCommitHash = commit.hash
                    }
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

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.regular)
            Text("正在加载...")
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text("暂无提交记录")
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - No Project View

    private var noProjectView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text("请先选择一个项目")
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Refresh

    /// 刷新提交列表
    /// - Parameter reason: 刷新原因，用于调试
    private func refresh(_ reason: String = "") {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            commits = []
            loading = false
            hasMoreCommits = true
            loadedCount = 0
            selectedCommitHash = nil
            return
        }

        // 取消之前的刷新任务
        currentRefreshTask?.cancel()

        loading = true
        loadedCount = 0
        hasMoreCommits = true
        selectedCommitHash = nil

        currentRefreshTask = Task {
            if Task.isCancelled { return }

            do {
                let newCommits = try await GitService.shared.getLog(
                    path: path,
                    count: pageSize,
                    branch: nil,
                    file: nil
                )

                if Task.isCancelled { return }

                await MainActor.run {
                    self.commits = newCommits
                    self.loading = false
                    self.loadedCount = newCommits.count
                    self.selectedCommitHash = newCommits.first?.hash
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run {
                    self.commits = []
                    self.loading = false
                }

                GitCommitHistoryPlugin.logger.error("刷新提交列表失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Load More

    /// 加载更多提交记录
    private func loadMoreCommits() {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty, !loading, hasMoreCommits else { return }

        loading = true

        let skipCount = loadedCount
        let currentPage = pageSize

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
                    self.loading = false
                }
                GitCommitHistoryPlugin.logger.error("加载更多提交失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GitCommitRow

/// 提交记录行视图
///
/// 参考 GitOK 的 CommitRow 实现，显示单个 Git 提交的信息。
struct GitCommitRow: View {
    let commit: GitCommitLog
    let isSelected: Bool

    /// 鼠标悬停状态
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                // 左侧竖线指示器
                VStack(spacing: 0) {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 8)

                // 主要内容
                VStack(alignment: .leading, spacing: 3) {
                    // 提交消息
                    Text(commit.message)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .foregroundColor(isSelected ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textPrimary.opacity(0.85))
                        .lineLimit(2)

                    // 作者 + 时间
                    HStack(spacing: 4) {
                        Text(commit.author)
                            .lineLimit(1)

                        Text("·")
                            .foregroundColor(.secondary.opacity(0.5))

                        Text(relativeTimeString(from: commit.date))
                            .lineLimit(1)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

                    // 提交哈希
                    Text(commit.hash.prefix(7))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.vertical, 6)
                .padding(.trailing, 8)

                Spacer()
            }
            .padding(.horizontal, 8)

            Divider()
                .padding(.leading, 24)
        }
        .contentShape(Rectangle())
        .background(rowBackground)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    /// 行背景：选中 > 悬停 > 默认
    private var rowBackground: some View {
        Group {
            if isSelected {
                Color.accentColor.opacity(0.08)
            } else if isHovered {
                Color.primary.opacity(0.04)
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Date Helper

    /// 将 ISO 格式日期字符串转为相对时间文本
    private func relativeTimeString(from dateString: String) -> String {
        let formatters = DateParseHelper.formatHandlers

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date.relativeTimeString
            }
        }

        // 回退：截取日期部分
        if dateString.count >= 10 {
            return String(dateString.prefix(10))
        }
        return dateString
    }
}

// MARK: - Date Extension

extension Date {
    /// 生成相对时间字符串（如 "3分钟前"、"2小时前"）
    var relativeTimeString: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 2592000 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else if interval < 31536000 {
            let months = Int(interval / 2592000)
            return "\(months)个月前"
        } else {
            let years = Int(interval / 31536000)
            return "\(years)年前"
        }
    }
}

/// 日期格式化辅助
enum DateParseHelper {
    /// 多种 ISO8601 格式尝试
    static let formatHandlers: [DateFormatter] = {
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
    /// 获取带跳过的提交日志（分页加载用）
    func getLogWithSkip(path: String?, count: Int, skip: Int, branch: String?) async throws -> [GitCommitLog] {
        let workDir = path.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        var args: [String] = [
            "log",
            "-\(count)",
            "--skip=\(skip)",
            "--pretty=format:%H|%an|%ae|%ai|%s",
        ]

        if let branch = branch {
            args.append(branch)
        }

        let output = try await runGitCommand(args: args, in: workDir)

        var logs: [GitCommitLog] = []

        for line in output.components(separatedBy: "\n").filtering({ !$0.isEmpty }) {
            let parts = line.components(separatedBy: "|")
            if parts.count >= 5 {
                logs.append(GitCommitLog(
                    hash: parts[0],
                    author: parts[1],
                    email: parts[2],
                    date: parts[3],
                    message: parts.dropFirst(4).joined(separator: "|")
                ))
            }
        }

        return logs
    }
}

// MARK: - Preview

#Preview {
    GitCommitHistorySidebarView()
        .inRootView()
        .frame(width: 250, height: 400)
}
