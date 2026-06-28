import LibGit2Swift
import SwiftUI
import LumiCoreKit
import LumiUI

/// Git 状态栏弹出面板
public struct GitPluginPopoverView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM
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
        .onChange(of: projectVM.currentProjectPath) { _, _ in
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
                        Text(shortDate(detail.date))
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
        GitDiffPanelView(
            selectedFile: selectedFile,
            oldText: oldText,
            newText: newText,
            isLoading: loadingDiff,
            loadingText: "Loading diff...",
            selectFileText: "Select a file to view diff",
            cannotDisplayText: "Cannot display diff for this file"
        )
    }

    private var filteredBranches: [GitBranch] {
        guard !branchSearch.isEmpty else { return branches }
        return branches.filter { $0.name.localizedCaseInsensitiveContains(branchSearch) }
    }

    private func refreshAll() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            branches = []
            commits = []
            uncommittedFiles = []
            selectedCommitHash = nil
            selectedFile = nil
            loading = false
            return
        }

        loading = true
        errorMessage = nil

        async let branchTask: [(name: String, isCurrent: Bool, message: String)] = Task.detached {
            let items = GitBranchService.listLocalBranches(at: path)
            return items.map {
                (name: $0.name, isCurrent: $0.isCurrent, message: $0.latestCommitMessage)
            }
        }.value

        async let commitTask = GitService.shared.getLog(path: path, count: commitPageSize, branch: nil, file: nil)
        async let fileTask = GitService.shared.getUncommittedChanges(path: path)

        do {
            let loadedBranchItems = await branchTask
            let loadedCommits = try await commitTask
            let loadedFiles = try await fileTask
            guard isCurrentRefresh(generation, path: path) else { return }
            branches = loadedBranchItems.map {
                GitBranch(id: $0.name, name: $0.name, isCurrent: $0.isCurrent, upstream: nil, latestCommitHash: "", latestCommitMessage: $0.message)
            }
            commits = loadedCommits
            uncommittedFiles = loadedFiles
            if selectedCommitHash == nil {
                selectedFile = loadedFiles.first?.path
            }
        } catch {
            guard isCurrentRefresh(generation, path: path) else { return }
            errorMessage = error.localizedDescription
        }

        if isCurrentRefresh(generation, path: path) {
            loading = false
        }
    }

    private func loadDetail(for hash: String?) async {
        detailGeneration += 1
        let generation = detailGeneration
        guard let hash else {
            selectedFile = uncommittedFiles.first?.path
            commitDetail = nil
            commitChangedFiles = []
            loadingDetail = false
            return
        }
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            loadingDetail = false
            return
        }

        loadingDetail = true
        do {
            let detail = try await GitService.shared.getCommitDetail(path: path, hash: hash)
            let files = try GitService.shared.getCommitChangedFiles(path: path, hash: hash)
            guard isCurrentDetail(generation, path: path, hash: hash) else { return }
            commitDetail = detail
            commitChangedFiles = files
            selectedFile = files.first?.path
        } catch {
            guard isCurrentDetail(generation, path: path, hash: hash) else { return }
            errorMessage = error.localizedDescription
        }
        if isCurrentDetail(generation, path: path, hash: hash) {
            loadingDetail = false
        }
    }

    private func loadDiff(for file: String?) async {
        diffGeneration += 1
        let generation = diffGeneration
        guard let file else {
            oldText = ""
            newText = ""
            loadingDiff = false
            return
        }
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            loadingDiff = false
            return
        }
        let hash = selectedCommitHash

        loadingDiff = true
        do {
            if let hash {
                let values = try await GitService.shared.getCommitFileContentChange(path: path, hash: hash, file: file)
                guard isCurrentDiff(generation, path: path, hash: hash, file: file) else { return }
                oldText = values.before ?? ""
                newText = values.after ?? ""
            } else {
                let values = try await GitService.shared.getUncommittedFileContentChange(path: path, file: file)
                guard isCurrentDiff(generation, path: path, hash: nil, file: file) else { return }
                oldText = values.before ?? ""
                newText = values.after ?? ""
            }
        } catch {
            guard isCurrentDiff(generation, path: path, hash: hash, file: file) else { return }
            oldText = ""
            newText = ""
            errorMessage = error.localizedDescription
        }
        if isCurrentDiff(generation, path: path, hash: hash, file: file) {
            loadingDiff = false
        }
    }

    private func isCurrentRefresh(_ generation: Int, path: String) -> Bool {
        refreshGeneration == generation && projectVM.currentProjectPath == path
    }

    private func isCurrentDetail(_ generation: Int, path: String, hash: String) -> Bool {
        detailGeneration == generation && projectVM.currentProjectPath == path && selectedCommitHash == hash
    }

    private func isCurrentDiff(_ generation: Int, path: String, hash: String?, file: String) -> Bool {
        diffGeneration == generation &&
            projectVM.currentProjectPath == path &&
            selectedCommitHash == hash &&
            selectedFile == file
    }

    private func checkout(branch: String) async {
        let path = projectVM.currentProjectPath
        actionMessage = "Switching to \(branch)..."
        do {
            try GitBranchService.checkout(branch: branch, at: path)
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionMessage = nil
    }

    private func createBranch(named name: String) async {
        let path = projectVM.currentProjectPath
        do {
            try GitBranchService.validateBranchName(name)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        actionMessage = "Creating branch \(name)..."
        do {
            try GitBranchService.createBranch(name, at: path)
            createBranchName = ""
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionMessage = nil
    }

    private func shortDate(_ value: String) -> String {
        value.count >= 10 ? String(value.prefix(10)) : value
    }
}

#Preview("Git Plugin Popover") {
    GitPluginPopoverView()
        .inRootView()
}
