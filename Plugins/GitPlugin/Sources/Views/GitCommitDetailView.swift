import SwiftUI
import SuperLogKit
import LumiCoreKit
import LumiUI

/// Git Commit 详情视图
///
/// 显示当前选中 commit 的完整信息，包括提交消息、作者、时间、
/// 变更统计，以及可交互的文件列表和 Diff 视图。
///
/// 当 selectedCommitHash 为 nil 时，显示当前工作区的未提交变更（工作状态模式）。
/// 工作区干净时，显示项目 Git 概览信息。
public struct GitCommitDetailView: View, SuperLog {

    // MARK: - 属性

    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    @ObservedObject var gitVM: AppGitVM

    // layoutState 从 lumiCore 获取
    private var layoutState: LumiLayoutState {
        lumiCore.layoutState ?? LumiLayoutState()
    }

    public init(lumiCore: LumiCoreAccessing, gitVM: AppGitVM) {
        self.lumiCore = lumiCore
        self.gitVM = gitVM
    }

    private var currentProjectPath: String {
        lumiCore.projectComponent.currentProject?.path ?? ""
    }

    private var currentProjectName: String {
        lumiCore.projectComponent.currentProject?.name ?? ""
    }

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

    /// 当前内容加载批次。用于丢弃项目或 commit 切换后的旧结果。
    @State private var loadGeneration: Int = 0

    /// 当前 diff 加载批次。用于丢弃文件切换后的旧结果。
    @State private var diffGeneration: Int = 0

    /// 未提交变更文件列表
    @State private var uncommittedFiles: [GitChangedFile] = []

    /// commit 模式下的变更文件列表（含变更类型）
    @State private var commitChangedFiles: [GitChangedFile] = []

    /// 是否正在加载未提交变更
    @State private var loadingWorkingState: Bool = false

    /// 项目 Git 概览信息（工作区干净时显示）
    @State private var projectGitInfo: GitCommitDetailService.ProjectGitInfo?

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            if gitVM.selectedCommitHash == nil {
                workingStateContent
            } else if let detail = commitDetail {
                commitDetailContent(detail)
            } else if loading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if lumiCore.projectComponent.currentProject != nil {
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
        .onChange(of: currentProjectPath) { _, _ in
            loadTask?.cancel()
            diffTask?.cancel()
            loadGeneration += 1
            diffGeneration += 1
            commitDetail = nil
            errorMessage = nil
            uncommittedFiles = []
            selectedFile = nil
            oldText = ""
            newText = ""
            loading = false
            loadingDiff = false
            loadingWorkingState = false
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
        if layoutState.activeViewContainerID != GitPlugin.info.id {
            layoutState.activateViewContainer(id: GitPlugin.info.id)
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
            GitCommitInputView(lumiCore: lumiCore, onCommitSuccess: {
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
                        .foregroundColor(theme.success)
                        .font(.appMicro)
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(theme.warning)
                        .font(.appMicro)
                }

                Text(LumiPluginLocalization.string("Working State", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                if !uncommittedFiles.isEmpty {
                    Text(verbatim: fileCountLabel(uncommittedFiles.count))
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.warning)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .appSurface(style: .subtle)
    }

    private var uncommittedFileListSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: fileCountLabel(uncommittedFiles.count))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .appSurface(style: .subtle)

            GlassDivider()

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
                    AppEmptyState(
                        icon: "checkmark.circle.fill",
                        title: LocalizedStringKey(LumiPluginLocalization.string("Clean Workspace", bundle: .module)),
                        description: LocalizedStringKey(LumiPluginLocalization.string("All changes committed", bundle: .module))
                    )
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
                    .font(.appTitle)
                    .foregroundColor(theme.primary)

                Text(currentProjectName)
                    .font(.appLargeTitle)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Spacer()
            }

            // 分支 + Remote + 干净状态
            HStack(spacing: 8) {
                // 分支 badge
                AppTag(info.branch, systemImage: "arrow.triangle.branch", style: .accent)

                // Remote badge
                if info.remote != "—" {
                    AppTag(info.remote, systemImage: "globe", style: .subtle)
                }

                Spacer()

                // 干净状态标识
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.appMicro)
                        .foregroundColor(theme.success)
                    Text(LumiPluginLocalization.string("Clean", bundle: .module))
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.success)
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
            GlassKeyValueRow(
                label: LumiPluginLocalization.string("Total Commits", bundle: .module),
                value: "\(info.totalCommits)"
            )

            // Contributors
            GlassKeyValueRow(
                label: LumiPluginLocalization.string("Contributors", bundle: .module),
                value: "\(info.contributors.count)"
            )

            Spacer()
        }
    }

    // MARK: - Repo Last Commit Section

    /// 最近提交区块
    private func repoLastCommitSection(_ info: GitCommitDetailService.ProjectGitInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 区块标题
            GlassSectionHeader(
                icon: "clock.arrow.circlepath",
                title: LumiPluginLocalization.string("Latest Commit", bundle: .module)
            )

            // Commit 内容卡片
            AppCard {
                VStack(alignment: .leading, spacing: 6) {
                    // Commit message
                    Text(info.lastCommitMessage)
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    GlassDivider()
                        .padding(.vertical, 2)

                    // 作者 + 时间
                    HStack(spacing: 12) {
                        // 作者
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle.fill")
                                .font(.appCaption)
                                .foregroundColor(theme.textTertiary)
                            Text(info.lastCommitAuthor)
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(1)
                        }

                        // 时间
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.appMicro)
                                .foregroundColor(theme.textTertiary)
                            Text(info.lastCommitDate)
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Repo Contributors Section

    /// 贡献者区块
    private func repoContributorsSection(_ info: GitCommitDetailService.ProjectGitInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 区块标题
            HStack(spacing: 5) {
                Image(systemName: "person.2")
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                Text(LumiPluginLocalization.string("Contributors", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textSecondary)

                Spacer()

                Text("\(info.contributors.count)")
                    .font(.appMonoMicro)
                    .foregroundColor(theme.textTertiary)
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
                                    .font(.appMicroEmphasized)
                                    .foregroundColor(.white)
                            )

                        Text(name)
                            .font(.appCaption)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .appSurface(style: .subtle, cornerRadius: 6)
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
                    .foregroundColor(theme.primary)
                    .font(.appMicro)
                    .padding(.top, 2)

                Text(detail.message)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
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
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .padding(.leading, 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .appSurface(style: .subtle)
    }

    private func metaLabel(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
            Text(value)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
        }
    }

    private func hashLabel(_ detail: GitCommitDetail) -> some View {
        HStack(spacing: 2) {
            Text(detail.hash.prefix(7))
                .font(.appMonoMicro)
                .foregroundColor(theme.textSecondary)

            AppIconButton(systemImage: isCopied ? "checkmark.circle.fill" : "doc.on.doc") {
                GitCommitDetailService.copyHash(detail.hash)
                withAnimation(.spring()) {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring()) {
                        isCopied = false
                    }
                }
            }
            .foregroundColor(isCopied ? theme.success : theme.textTertiary)
        }
    }

    private func statsBadges(_ stats: GitDiffStats) -> some View {
        HStack(spacing: 8) {
            statBadge(value: "\(stats.filesChanged)", label: LumiPluginLocalization.string("files", bundle: .module), color: theme.textPrimary)
            statBadge(value: "+\(stats.insertions)", label: nil, color: theme.success)
            statBadge(value: "-\(stats.deletions)", label: nil, color: theme.error)
        }
    }

    private func statBadge(value: String, label: String?, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.appMonoMicro)
                .foregroundColor(color)
            if let label = label {
                Text(label)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    private func fileListSection(_ detail: GitCommitDetail) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: fileCountLabel(commitChangedFiles.count))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .appSurface(style: .subtle)

            GlassDivider()

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
        AppEmptyState(
            icon: "doc.text",
            title: LocalizedStringKey(LumiPluginLocalization.string("No file changes in this commit", bundle: .module))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.regular)
            Text(LumiPluginLocalization.string("Loading...", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        AppErrorBanner(message: LocalizedStringKey(error))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noSelectionView: some View {
        AppEmptyState(
            icon: "circle.circle",
            title: LocalizedStringKey(LumiPluginLocalization.string("Please select a commit from the sidebar", bundle: .module))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noProjectView: some View {
        AppEmptyState(
            icon: "folder.badge.questionmark",
            title: LocalizedStringKey(LumiPluginLocalization.string("Please select a project first", bundle: .module))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 数据加载

    /// 加载工作状态（未提交变更）
    private func loadWorkingState() {
        let path = currentProjectPath
        guard !path.isEmpty else {
            loadTask?.cancel()
            loadGeneration += 1
            uncommittedFiles = []
            loadingWorkingState = false
            projectGitInfo = nil
            return
        }

        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        loadingWorkingState = true

        loadTask = Task {
            async let filesTask: [GitChangedFile] = {
                do {
                    return try await GitCommitDetailService.loadUncommittedFiles(path: path)
                } catch {
                    if GitPlugin.verbose {
                                            GitPlugin.logger.error("\(Self.t)加载未提交变更失败: \(error.localizedDescription)")
                    }
                    return []
                }
            }()
            async let infoTask = GitCommitDetailService.loadProjectGitInfo(path: path)

            let files = await filesTask
            let info = await infoTask

            if Task.isCancelled { return }

            guard self.loadGeneration == generation,
                  self.currentProjectPath == path,
                  self.gitVM.selectedCommitHash == nil else { return }

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
        let path = currentProjectPath

        guard let hash = hash, !path.isEmpty else {
            loadTask?.cancel()
            loadGeneration += 1
            commitDetail = nil
            commitChangedFiles = []
            loading = false
            errorMessage = nil
            return
        }

        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        loading = true
        errorMessage = nil

        loadTask = Task {
            do {
                let (detail, files) = try await GitCommitDetailService.loadCommitDetail(
                    path: path,
                    hash: hash
                )

                if Task.isCancelled { return }

                guard self.loadGeneration == generation,
                      self.currentProjectPath == path,
                      self.gitVM.selectedCommitHash == hash else { return }
                self.commitDetail = detail
                self.commitChangedFiles = files
                self.loading = false
                self.selectedFile = files.first?.path
            } catch {
                if Task.isCancelled { return }

                guard self.loadGeneration == generation,
                      self.currentProjectPath == path,
                      self.gitVM.selectedCommitHash == hash else { return }
                self.commitDetail = nil
                self.commitChangedFiles = []
                self.loading = false
                self.errorMessage = error.localizedDescription

                if GitPlugin.verbose {
                                    GitPlugin.logger.error("\(Self.t)加载 commit 详情失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 加载选中文件的 diff 内容
    private func loadFileDiff(file: String?) {
        diffTask?.cancel()
        diffGeneration += 1

        guard let file = file,
              !currentProjectPath.isEmpty else {
            oldText = ""
            newText = ""
            loadingDiff = false
            return
        }

        let generation = diffGeneration
        loadingDiff = true

        let path = currentProjectPath
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
                    guard self.diffGeneration == generation,
                          self.selectedFile == file,
                          self.currentProjectPath == path,
                          self.gitVM.selectedCommitHash == hash else { return }
                    self.oldText = before
                    self.newText = after
                    self.loadingDiff = false
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run {
                    guard self.diffGeneration == generation,
                          self.selectedFile == file,
                          self.currentProjectPath == path,
                          self.gitVM.selectedCommitHash == hash else { return }
                    self.oldText = ""
                    self.newText = ""
                    self.loadingDiff = false
                }

                if GitPlugin.verbose {
                                    GitPlugin.logger.error("\(Self.t)加载文件 diff 失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func fileCountLabel(_ count: Int) -> String {
        let unitKey = count == 1 ? "file" : "files"
        return "\(count) \(LumiPluginLocalization.string(unitKey, bundle: .module))"
    }
}

// MARK: - Flow Layout

/// 简单的流式布局，用于自动换行显示标签
private struct FlowLayout: Layout {
    public var spacing: CGFloat = 4

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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
    GitCommitDetailView(lumiCore: PreviewGitSupport.lumiCore, gitVM: PreviewGitSupport.gitVM)
        .inRootView()
        .frame(width: 700, height: 600)
}
