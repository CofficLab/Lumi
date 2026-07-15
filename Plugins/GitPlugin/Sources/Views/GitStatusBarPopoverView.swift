import LibGit2Swift
import SwiftUI
import LumiCoreKit
import LumiUI
import MagicDiffView

/// Git 状态栏弹出面板
public struct GitPluginPopoverView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing


    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }
    @State private var branches: [GitBranch] = []
    @State private var commits: [GitCommitLog] = []
    @State private var uncommittedFiles: [GitChangedFile] = []
    @State private var selectedCommitHash: String?
    @State private var selectedFile: String?
    @State private var commitDetail: GitCommitDetail?
    @State private var commitChangedFiles: [GitChangedFile] = []
    @State private var oldText = ""
    @State private var newText = ""
    @State private var branchSearch = ""
    @State private var loading = false
    @State private var loadingDetail = false
    @State private var loadingDiff = false
    @State private var actionMessage: String?
    @State private var errorMessage: String?
    @State private var showCreateBranchAlert = false
    @State private var createBranchName = ""
    @State private var refreshGeneration = 0
    @State private var detailGeneration = 0
    @State private var diffGeneration = 0

    private let commitPageSize = 25

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            commitInput
            Divider()

            if let errorMessage {
                Text(errorMessage)
                    .font(.appCaption)
                    .foregroundColor(theme.warning)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
            }

            HSplitView {
                leftPanel
                    .frame(minWidth: 290, idealWidth: 340, maxWidth: 380)
                rightPanel
            }

            if let actionMessage {
                Divider()
                Text(actionMessage)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 620)
        .task { await refreshAll() }
        .onChange(of: currentProjectPath) { _, _ in
            Task { await refreshAll() }
        }
        .onApplicationDidBecomeActive {
            Task { await refreshAll() }
        }
        .onChange(of: selectedCommitHash) { _, newHash in
            selectedFile = nil
            oldText = ""
            newText = ""
            Task { await loadDetail(for: newHash) }
        }
        .onChange(of: selectedFile) { _, file in
            Task { await loadDiff(for: file) }
        }
        .alert(LumiPluginLocalization.string("Create New Branch", bundle: .module), isPresented: $showCreateBranchAlert) {
            TextField(LumiPluginLocalization.string("Branch name", bundle: .module), text: $createBranchName)
            Button(LumiPluginLocalization.string("Cancel", bundle: .module), role: .cancel) {}
            Button(LumiPluginLocalization.string("Create", bundle: .module)) {
                let branchName = createBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !branchName.isEmpty else { return }
                Task { await createBranch(named: branchName) }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
            TextField(LumiPluginLocalization.string("Search branches...", bundle: .module), text: $branchSearch)
                .font(.appCaption)
                .textFieldStyle(.plain)
            Spacer()
            AppIconButton(systemImage: "arrow.clockwise") {
                Task { await refreshAll() }
            }
            AppIconButton(systemImage: "plus") {
                showCreateBranchAlert = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var commitInput: some View {
        GitCommitInputView(style: .compact) {
            Task { await refreshAll() }
        }
    }

    private var leftPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumiPluginLocalization.string("Branches", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textSecondary)
                branchList
                GlassDivider().padding(.vertical, 4)
                Text(LumiPluginLocalization.string("Commit History", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textSecondary)
                commitList
            }
            .padding(10)
        }
    }

    private var rightPanel: some View {
        VStack(spacing: 0) {
            if loading || loadingDetail {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedCommitHash == nil {
                workingStateDetail
            } else {
                commitDetailView
            }
        }
    }

    private var branchList: some View {
        VStack(spacing: 4) {
            ForEach(filteredBranches) { branch in
                Button {
                    Task { await checkout(branch: branch.name) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: branch.isCurrent ? "checkmark" : "arrow.triangle.branch")
                            .font(.appCaption)
                            .foregroundColor(branch.isCurrent ? theme.primary : theme.textTertiary)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(branch.name)
                                .font(branch.isCurrent ? .appCaptionEmphasized : .appCaption)
                                .foregroundColor(theme.textPrimary)
                            if !branch.latestCommitMessage.isEmpty {
                                Text(branch.latestCommitMessage)
                                    .font(.appMicro)
                                    .foregroundColor(theme.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(branch.isCurrent ? theme.primary.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(branch.isCurrent)
            }
        }
    }

    private var filteredBranches: [GitBranch] {
        if branchSearch.isEmpty {
            return branches
        }
        return branches.filter { $0.name.localizedCaseInsensitiveContains(branchSearch) }
    }

    private var commitList: some View {
        VStack(spacing: 0) {
            Button {
                selectedCommitHash = nil
                selectedFile = uncommittedFiles.first?.path
            } label: {
                HStack {
                    Image(systemName: uncommittedFiles.isEmpty ? "checkmark.circle" : "clock.arrow.circlepath")
                        .foregroundColor(uncommittedFiles.isEmpty ? theme.success : theme.warning)
                    Text(uncommittedFiles.isEmpty ? "Clean working tree" : "Working state (\(uncommittedFiles.count))")
                        .font(.appCaptionEmphasized)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)

            GlassDivider()
            ForEach(commits, id: \.hash) { commit in
                GitCommitListRow(
                    commit: commit,
                    isSelected: selectedCommitHash == commit.hash,
                    style: .compact,
                    action: {
                        selectedCommitHash = commit.hash
                    }
                )
                GlassDivider()
            }
        }
    }

    private var workingStateDetail: some View {
        HSplitView {
            List(uncommittedFiles, id: \.path, selection: $selectedFile) { file in
                GitChangedFileRow(file: file)
            }
            .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)

            diffPanel
        }
    }

    private var commitDetailView: some View {
        VStack(spacing: 0) {
            if let detail = commitDetail {
                VStack(alignment: .leading, spacing: 6) {
                    Text(detail.message)
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                    HStack(spacing: 10) {
                        Text(detail.author)
                        Text(detail.date)
                        Text(String(detail.hash.prefix(7)))
                            .font(.appMonoMicro)
                    }
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                GlassDivider()
            }

            HSplitView {
                List(commitChangedFiles, id: \.path, selection: $selectedFile) { file in
                    GitChangedFileRow(file: file)
                }
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)

                diffPanel
            }
        }
    }

    private var diffPanel: some View {
        Group {
            if loadingDiff {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedFile != nil {
                MagicDiffView(
                    oldText: oldText,
                    newText: newText,
                    enableCollapsing: true,
                    minUnchangedLines: 3
                )
            } else {
                Text(LumiPluginLocalization.string("Select a file to view diff", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Data Loading

    private func refreshAll() async {
        let path = currentProjectPath
        guard !path.isEmpty else { return }

        let generation = refreshGeneration
        guard refreshGeneration == generation else { return }

        loading = true
        errorMessage = nil
        actionMessage = nil

        do {
            // 分支列表使用 GitBranchService.listLocalBranches
            let branchesResult = GitBranchService.listLocalBranches(at: path)

            // 提交历史使用 GitService.shared.getLog
            async let commitsTask = GitService.shared.getLog(path: path, count: commitPageSize, branch: nil, file: nil)

            // 工作区状态使用 GitService.shared.getUncommittedChanges
            async let statusTask = GitService.shared.getUncommittedChanges(path: path)

            let commitsResult = try await commitsTask
            let statusResult = try await statusTask

            guard refreshGeneration == generation else { return }

            self.branches = branchesResult
            self.commits = commitsResult
            self.uncommittedFiles = statusResult

            if !statusResult.isEmpty {
                selectedFile = statusResult.first?.path
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        loading = false
    }

    private func loadDetail(for hash: String?) async {
        guard let hash else { return }

        let path = currentProjectPath
        guard !path.isEmpty else { return }

        let generation = detailGeneration
        loadingDetail = true

        do {
            async let detailTask = GitService.shared.getCommitDetail(path: path, hash: hash)
            async let filesTask = GitService.shared.getCommitChangedFiles(path: path, hash: hash)

            let detail = try await detailTask
            let files = try await filesTask

            guard detailGeneration == generation else { return }

            self.commitDetail = detail
            self.commitChangedFiles = files
        } catch {
            self.errorMessage = error.localizedDescription
        }

        loadingDetail = false
    }

    private func loadDiff(for file: String?) async {
        guard let file else {
            oldText = ""
            newText = ""
            return
        }

        let path = currentProjectPath
        guard !path.isEmpty else { return }

        let generation = diffGeneration
        loadingDiff = true

        do {
            let (old, new) = try await GitCommitDetailService.loadFileDiff(
                file: file,
                projectPath: path,
                commitHash: selectedCommitHash
            )

            guard diffGeneration == generation else { return }

            self.oldText = old
            self.newText = new
        } catch {
            self.oldText = ""
            self.newText = ""
        }

        loadingDiff = false
    }

    // MARK: - Actions

    private func checkout(branch: String) async {
        let path = currentProjectPath
        guard !path.isEmpty else { return }

        actionMessage = nil

        do {
            try GitBranchService.checkout(branch: branch, at: path)
            await refreshAll()
            actionMessage = "Switched to \(branch)"
        } catch {
            actionMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func createBranch(named name: String) async {
        let path = currentProjectPath
        guard !path.isEmpty else { return }

        actionMessage = nil

        do {
            try GitBranchService.createBranch(name, at: path)
            await refreshAll()
            actionMessage = "Created branch \(name)"
        } catch {
            actionMessage = "Error: \(error.localizedDescription)"
        }
    }
}
