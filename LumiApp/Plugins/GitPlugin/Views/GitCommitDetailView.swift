import SwiftUI

/// Git Commit 详情视图
///
/// 显示当前选中 commit 的完整信息，包括提交消息、作者、时间、
/// 变更统计，以及可交互的文件列表和 Diff 视图。
///
/// 当 selectedCommitHash 为 nil 时，显示当前工作区的未提交变更（工作状态模式）。
/// 工作区干净时，显示项目 Git 概览信息。
struct GitCommitDetailView: View {

    // MARK: - 属性

    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject var gitVM: AppGitVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM

    /// 当前加载的 commit 详情
    @State private var commitDetail: GitCommitDetail?

    /// 是否正在加载
    @State private var loading = false

    /// 错误信息
    @State private var errorMessage: String?

    /// Hash 是否已复制
    @State private var isCopied = false

    /// 当前选中的文件（用于文件列表高亮）
    @State private var selectedFile: String?

    /// Diff 视图相关状态
    @State private var oldText: String = ""
    @State private var newText: String = ""
    @State private var loadingDiff: Bool = false
    @State private var diffTask: Task<Void, Never>?

    /// 当前加载任务
    @State private var loadTask: Task<Void, Never>?

    /// 未提交变更文件列表
    @State private var uncommittedFiles: [GitChangedFile] = []

    /// commit 模式下的变更文件列表（含变更类型）
    @State private var commitChangedFiles: [GitChangedFile] = []

    /// 是否正在加载未提交变更
    @State private var loadingWorkingState: Bool = false

    /// 项目 Git 概览信息（工作区干净时显示）
    @State private var projectGitInfo: GitCommitDetailService.ProjectGitInfo?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if gitVM.selectedCommitHash == nil {
                workingStateContent
            } else if let detail = commitDetail {
                commitDetailContent(detail)
            } else if loading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if projectVM.isProjectSelected {
                noSelectionView
            } else {
                noProjectView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            activateCommitHistorySidebar()
            handleSelectionChange()
        }
        .onChange(of: gitVM.selectedCommitHash) { _, _ in
            selectedFile = nil
            oldText = ""
            newText = ""
            handleSelectionChange()
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            commitDetail = nil
            errorMessage = nil
            uncommittedFiles = []
            selectedFile = nil
            oldText = ""
            newText = ""
            projectGitInfo = nil
            handleSelectionChange()
        }
        .onChange(of: selectedFile) { _, newFile in
            loadFileDiff(file: newFile)
        }
    }

    // MARK: - 私有方法

    /// 当 Detail 视图出现时，激活左侧栏的 Commit History 标签
    private func activateCommitHistorySidebar() {
        if layoutVM.selectedAgentSidebarTabId != GitPlugin.id {
            layoutVM.selectAgentSidebarTab(GitPlugin.id, reason: "CommitDetail: view appeared")
        }
    }

    /// 根据当前选中状态决定加载工作状态还是 commit 详情
    private func handleSelectionChange() {
        if gitVM.selectedCommitHash == nil {
            loadWorkingState()
        } else {
            loadCommitDetail()
        }
    }

    // MARK: - Working State Views

    private var workingStateContent: some View {
        VStack(spacing: 0) {
            // Commit 输入区域（顶部）
            GitCommitInputView(onCommitSuccess: {
                loadWorkingState()
            })

            Divider()

            workingStateSummary

            Divider()

            if !uncommittedFiles.isEmpty {
                // 文件列表 + Diff
                HSplitView {
                    uncommittedFileListSection
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

                    diffViewSection
                }
            } else if loadingWorkingState {
                loadingView
            } else {
                cleanWorkspaceView
            }
        }
    }

    private var workingStateSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if uncommittedFiles.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                }

                Text(String(localized: "Working State", table: "GitPlugin"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer()

                if !uncommittedFiles.isEmpty {
                    Text(String(localized: "\(uncommittedFiles.count) \(uncommittedFiles.count == 1 ? "file" : "files")", table: "GitPlugin"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var uncommittedFileListSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "\(uncommittedFiles.count) \(uncommittedFiles.count == 1 ? "file" : "files")", table: "GitPlugin"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List(uncommittedFiles, id: \.path, selection: $selectedFile) { file in
                GitChangedFileRow(file: file)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Clean Workspace View

    /// 工作区干净时的仓库概览视图，参考 GitOK 的仓库信息区块设计
    private var cleanWorkspaceView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let info = projectGitInfo {
                    repoOverviewContent(info)
                } else {
                    // 无信息时的简单提示
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                        Text(String(localized: "Clean Workspace", table: "GitPlugin"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        Text(String(localized: "All changes committed", table: "GitPlugin"))
                            .font(.system(size: 11))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                    .padding(.top, 40)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Repo Overview Content

    /// 仓库概览主内容：仓库标题 + 统计指标 + 最近提交 + 贡献者
    private func repoOverviewContent(_ info: GitCommitDetailService.ProjectGitInfo) -> some View {
        VStack(spacing: 0) {
            // 顶部区域：仓库名 + 分支 + 状态
            repoHeaderSection(info)

            Divider()
                .padding(.horizontal, 16)

            // 统计指标卡片行
            repoStatsRow(info)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Divider()
                .padding(.horizontal, 16)

            // 最近提交
            repoLastCommitSection(info)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // 贡献者（仅在有人时显示）
            if !info.contributors.isEmpty {
                Divider()
                    .padding(.horizontal, 16)

                repoContributorsSection(info)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Repo Header

    /// 仓库头部：仓库名称、分支 badge、干净状态
    private func repoHeaderSection(_ info: GitCommitDetailService.ProjectGitInfo) -> some View {
        VStack(spacing: 8) {
            // 仓库名称
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "7C6FFF"))

                Text(projectVM.currentProjectName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .lineLimit(1)

                Spacer()
            }

            // 分支 + Remote + 干净状态
            HStack(spacing: 8) {
                // 分支 badge
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9))
                    Text(info.branch)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundColor(Color(hex: "0A84FF"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "0A84FF").opacity(0.1))
                .cornerRadius(4)

                // Remote badge
                if info.remote != "—" {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 9))
                        Text(info.remote)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(4)
                }

                Spacer()

                // 干净状态标识
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(String(localized: "Clean", table: "GitPlugin"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Repo Stats Row

    /// 统计指标卡片行：Total Commits / Contributors
    private func repoStatsRow(_ info: GitCommitDetailService.ProjectGitInfo) -> some View {
        HStack(spacing: 10) {
            // Total Commits
            repoStatCard(
                icon: "sourcecontrol",
                iconColor: Color(hex: "7C6FFF"),
                value: "\(info.totalCommits)",
                label: String(localized: "Total Commits", table: "GitPlugin")
            )

            // Contributors
            repoStatCard(
                icon: "person.2.fill",
                iconColor: Color(hex: "FF9F0A"),
                value: "\(info.contributors.count)",
                label: String(localized: "Contributors", table: "GitPlugin")
            )

            Spacer()
        }
    }

    /// 单个统计指标卡片
    private func repoStatCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Repo Last Commit Section

    /// 最近提交区块
    private func repoLastCommitSection(_ info: GitCommitDetailService.ProjectGitInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 区块标题
            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                Text(String(localized: "Latest Commit", table: "GitPlugin"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }

            // Commit 内容卡片
            VStack(alignment: .leading, spacing: 6) {
                // Commit message
                Text(info.lastCommitMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .lineLimit(2)
                    .textSelection(.enabled)

                Divider()
                    .padding(.vertical, 2)

                // 作者 + 时间
                HStack(spacing: 12) {
                    // 作者
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(info.lastCommitAuthor)
                            .font(.system(size: 11))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            .lineLimit(1)
                    }

                    // 时间
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(info.lastCommitDate)
                            .font(.system(size: 11))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }

    // MARK: - Repo Contributors Section

    /// 贡献者区块
    private func repoContributorsSection(_ info: GitCommitDetailService.ProjectGitInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 区块标题
            HStack(spacing: 5) {
                Image(systemName: "person.2")
                    .font(.system(size: 10))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                Text(String(localized: "Contributors", table: "GitPlugin"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                Spacer()

                Text("\(info.contributors.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "98989E"))
            }

            // 贡献者列表
            FlowLayout(spacing: 6) {
                ForEach(info.contributors.prefix(12), id: \.self) { name in
                    HStack(spacing: 4) {
                        // 基于名字生成固定颜色的圆形头像
                        Circle()
                            .fill(Color.adaptive(from: name))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text(String(name.prefix(1)).uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        Text(name)
                            .font(.system(size: 11))
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Commit Detail Views

    private func commitDetailContent(_ detail: GitCommitDetail) -> some View {
        VStack(spacing: 0) {
            commitSummarySection(detail)

            Divider()

            if !detail.changedFiles.isEmpty {
                HSplitView {
                    fileListSection(detail)
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

                    diffViewSection
                }
            } else {
                noFilesView
            }
        }
    }

    private func commitSummarySection(_ detail: GitCommitDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "circle.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 10))
                    .padding(.top, 2)

                Text(detail.message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()
            }

            HStack(spacing: 12) {
                metaLabel(icon: "person.fill", value: detail.author)
                metaLabel(icon: "clock.fill", value: GitCommitDetailService.formattedDate(detail.date))
                hashLabel(detail)

                if let stats = detail.stats {
                    Spacer()
                    statsBadges(stats)
                }
            }

            if !detail.body.isEmpty {
                Text(detail.body)
                    .font(.system(size: 11))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .padding(.leading, 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func metaLabel(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                .lineLimit(1)
        }
    }

    private func hashLabel(_ detail: GitCommitDetail) -> some View {
        HStack(spacing: 2) {
            Text(detail.hash.prefix(7))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            Button {
                GitCommitDetailService.copyHash(detail.hash)
                withAnimation(.spring()) {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring()) {
                        isCopied = false
                    }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundColor(isCopied ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func statsBadges(_ stats: GitDiffStats) -> some View {
        HStack(spacing: 8) {
            statBadge(value: "\(stats.filesChanged)", label: String(localized: "files", table: "GitPlugin"), color: Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            statBadge(value: "+\(stats.insertions)", label: nil, color: .green)
            statBadge(value: "-\(stats.deletions)", label: nil, color: .red)
        }
    }

    private func statBadge(value: String, label: String?, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(color)
            if let label = label {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }
        }
    }

    private func fileListSection(_ detail: GitCommitDetail) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "\(commitChangedFiles.count) \(commitChangedFiles.count == 1 ? "file" : "files")", table: "GitPlugin"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List(commitChangedFiles, id: \.path, selection: $selectedFile) { file in
                GitChangedFileRow(file: file)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Diff View

    private var diffViewSection: some View {
        GitDiffPanelView(
            selectedFile: selectedFile,
            oldText: oldText,
            newText: newText,
            isLoading: loadingDiff
        )
    }
    // MARK: - State Views

    private var noFilesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.4))
            Text(String(localized: "No file changes in this commit", table: "GitPlugin"))
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.regular)
            Text(String(localized: "Loading...", table: "GitPlugin"))
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange.opacity(0.6))
            Text(String(localized: "Failed to load", table: "GitPlugin"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noSelectionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.circle")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(String(localized: "Please select a commit from the sidebar", table: "GitPlugin"))
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noProjectView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(String(localized: "Please select a project first", table: "GitPlugin"))
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 数据加载

    /// 加载工作状态（未提交变更）
    private func loadWorkingState() {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            uncommittedFiles = []
            loadingWorkingState = false
            projectGitInfo = nil
            return
        }

        loadingWorkingState = true

        Task {
            async let filesTask: [GitChangedFile] = {
                do {
                    return try await GitCommitDetailService.loadUncommittedFiles(path: path)
                } catch {
                    if GitPlugin.verbose {
                                            GitPlugin.logger.error("加载未提交变更失败: \(error.localizedDescription)")
                    }
                    return []
                }
            }()
            async let infoTask = GitCommitDetailService.loadProjectGitInfo(path: path)

            let files = await filesTask
            let info = await infoTask

            self.uncommittedFiles = files
            self.loadingWorkingState = false
            self.selectedFile = files.first?.path

            // 只在工作区干净时显示项目信息
            if files.isEmpty {
                self.projectGitInfo = info
            } else {
                self.projectGitInfo = nil
            }
        }
    }

    /// 加载 commit 详情
    private func loadCommitDetail() {
        let hash = gitVM.selectedCommitHash
        let path = projectVM.currentProjectPath

        guard let hash = hash, !path.isEmpty else {
            commitDetail = nil
            commitChangedFiles = []
            loading = false
            errorMessage = nil
            return
        }

        loadTask?.cancel()
        loading = true
        errorMessage = nil

        loadTask = Task {
            do {
                let (detail, files) = try await GitCommitDetailService.loadCommitDetail(
                    path: path,
                    hash: hash
                )

                if Task.isCancelled { return }

                guard self.gitVM.selectedCommitHash == hash else { return }
                self.commitDetail = detail
                self.commitChangedFiles = files
                self.loading = false
                self.selectedFile = files.first?.path
            } catch {
                if Task.isCancelled { return }

                self.commitDetail = nil
                self.commitChangedFiles = []
                self.loading = false
                self.errorMessage = error.localizedDescription

                if GitPlugin.verbose {
                                    GitPlugin.logger.error("加载 commit 详情失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 加载选中文件的 diff 内容
    private func loadFileDiff(file: String?) {
        diffTask?.cancel()

        guard let file = file,
              !projectVM.currentProjectPath.isEmpty else {
            oldText = ""
            newText = ""
            return
        }

        loadingDiff = true

        let path = projectVM.currentProjectPath
        let hash = gitVM.selectedCommitHash

        diffTask = Task.detached(priority: .userInitiated) {
            do {
                let (before, after) = try await GitCommitDetailService.loadFileDiff(
                    file: file,
                    projectPath: path,
                    commitHash: hash
                )

                if Task.isCancelled { return }

                await MainActor.run {
                    guard self.selectedFile == file else { return }
                    self.oldText = before
                    self.newText = after
                    self.loadingDiff = false
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run {
                    self.oldText = ""
                    self.newText = ""
                    self.loadingDiff = false
                }

                if GitPlugin.verbose {
                                    GitPlugin.logger.error("加载文件 diff 失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Flow Layout

/// 简单的流式布局，用于自动换行显示标签
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - 预览

#Preview("GitCommitDetail") {
    GitCommitDetailView()
        .inRootView()
        .frame(width: 700, height: 600)
}
