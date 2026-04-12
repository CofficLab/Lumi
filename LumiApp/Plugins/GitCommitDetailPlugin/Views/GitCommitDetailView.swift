import MagicDiffView
import SwiftUI
import MagicKit

/// Git Commit 详情视图
///
/// 显示当前选中 commit 的完整信息，包括提交消息、作者、时间、
/// 变更统计，以及可交互的文件列表和 Diff 视图。
///
/// 当 selectedCommitHash 为 nil 时，显示当前工作区的未提交变更（工作状态模式）。
/// 工作区干净时，显示项目 Git 概览信息。
struct GitCommitDetailView: View {

    // MARK: - 属性

    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject var gitVM: GitVM
    @EnvironmentObject private var layoutVM: LayoutVM

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
        if layoutVM.selectedAgentSidebarTabId != GitCommitHistoryPlugin.id {
            layoutVM.selectAgentSidebarTab(GitCommitHistoryPlugin.id)
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
            workingStateSummary

            Divider()

            if !uncommittedFiles.isEmpty {
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

                Text(String(localized: "Working State", table: "GitCommitDetail"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Spacer()

                if !uncommittedFiles.isEmpty {
                    Text(String(localized: "\(uncommittedFiles.count) \(uncommittedFiles.count == 1 ? "file" : "files")", table: "GitCommitDetail"))
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
                Text(String(localized: "\(uncommittedFiles.count) \(uncommittedFiles.count == 1 ? "file" : "files")", table: "GitCommitDetail"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List(uncommittedFiles, id: \.path, selection: $selectedFile) { file in
                fileRow(file)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Clean Workspace View

    private var cleanWorkspaceView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部：干净状态提示
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    Text(String(localized: "Clean Workspace", table: "GitCommitDetail"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                    Text(String(localized: "All changes committed", table: "GitCommitDetail"))
                        .font(.system(size: 11))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
                .padding(.top, 24)

                // 项目信息区域
                if let info = projectGitInfo {
                    projectInfoGrid(info)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func projectInfoGrid(_ info: GitCommitDetailService.ProjectGitInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(String(localized: "Project Info", table: "GitCommitDetail"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }

            VStack(spacing: 1) {
                projectInfoRow(icon: "arrow.triangle.branch", label: String(localized: "Branch", table: "GitCommitDetail"), value: info.branch)
                projectInfoRow(icon: "globe", label: String(localized: "Remote", table: "GitCommitDetail"), value: info.remote)
                projectInfoRow(icon: "number.circle", label: String(localized: "Total Commits", table: "GitCommitDetail"), value: "\(info.totalCommits)")
                projectInfoRow(icon: "person.2", label: String(localized: "Contributors", table: "GitCommitDetail"), value: "\(info.contributors.count)")

                if !info.contributors.isEmpty {
                    contributorsList(info.contributors)
                }

                Divider()
                    .padding(.vertical, 4)

                projectInfoRow(icon: "text.bubble", label: String(localized: "Last Commit", table: "GitCommitDetail"), value: info.lastCommitMessage)
                projectInfoRow(icon: "person.fill", label: String(localized: "Author", table: "GitCommitDetail"), value: info.lastCommitAuthor)
                projectInfoRow(icon: "clock.fill", label: String(localized: "Date", table: "GitCommitDetail"), value: info.lastCommitDate)
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
    }

    private func projectInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .lineLimit(2)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func contributorsList(_ contributors: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 14)

                Text(String(localized: "Team", table: "GitCommitDetail"))
                    .font(.system(size: 11))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(width: 80, alignment: .leading)

                FlowLayout(spacing: 4) {
                    ForEach(contributors.prefix(8), id: \.self) { name in
                        HStack(spacing: 3) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(name)
                                .font(.system(size: 10))
                                .foregroundColor(AppUI.Color.semantic.textPrimary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
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
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
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
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
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
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .lineLimit(1)
        }
    }

    private func hashLabel(_ detail: GitCommitDetail) -> some View {
        HStack(spacing: 2) {
            Text(detail.hash.prefix(7))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

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
            statBadge(value: "\(stats.filesChanged)", label: String(localized: "files", table: "GitCommitDetail"), color: AppUI.Color.semantic.textPrimary)
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
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
        }
    }

    private func fileListSection(_ detail: GitCommitDetail) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "\(commitChangedFiles.count) \(commitChangedFiles.count == 1 ? "file" : "files")", table: "GitCommitDetail"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List(commitChangedFiles, id: \.path, selection: $selectedFile) { file in
                fileRow(file)
            }
            .listStyle(.plain)
        }
    }

    private func fileRow(_ file: GitChangedFile) -> some View {
        HStack(spacing: 6) {
            Image(systemName: GitCommitDetailService.fileIcon(for: file.path))
                .font(.system(size: 10))
                .foregroundColor(GitCommitDetailService.fileIconColor(for: file.path))

            Text(file.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            Text(file.changeType.displayLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(file.changeType.color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(file.changeType.color.opacity(0.1))
                .cornerRadius(3)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    // MARK: - Diff View

    private var diffViewSection: some View {
        VStack(spacing: 0) {
            if let file = selectedFile {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))

                    Text(file)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                if loadingDiff {
                    VStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(String(localized: "Loading diff...", table: "GitCommitDetail"))
                            .font(.system(size: 10))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if oldText.isEmpty && newText.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(String(localized: "Cannot display diff for this file", table: "GitCommitDetail"))
                            .font(.system(size: 10))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MagicDiffView(
                        oldText: oldText,
                        newText: newText,
                        enableCollapsing: true,
                        minUnchangedLines: 3
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(String(localized: "Select a file to view diff", table: "GitCommitDetail"))
                        .font(.system(size: 11))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - State Views

    private var noFilesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.4))
            Text(String(localized: "No file changes in this commit", table: "GitCommitDetail"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.regular)
            Text(String(localized: "Loading...", table: "GitCommitDetail"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange.opacity(0.6))
            Text(String(localized: "Failed to load", table: "GitCommitDetail"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
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
            Text(String(localized: "Please select a commit from the sidebar", table: "GitCommitDetail"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noProjectView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(String(localized: "Please select a project first", table: "GitCommitDetail"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
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
                    GitCommitDetailPlugin.logger.error("加载未提交变更失败: \(error.localizedDescription)")
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

                GitCommitDetailPlugin.logger.error("加载 commit 详情失败: \(error.localizedDescription)")
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

                GitCommitDetailPlugin.logger.error("加载文件 diff 失败: \(error.localizedDescription)")
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
