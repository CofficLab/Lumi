import MagicKit
import LibGit2Swift
import SwiftUI

/// Git 状态栏弹出面板
struct GitPluginPopoverView: View {
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

    private let commitPageSize = 25

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            commitInput
            Divider()

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
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
                    .font(.system(size: 11))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
        .alert("Create New Branch", isPresented: $showCreateBranchAlert) {
            TextField("Branch name", text: $createBranchName)
            Button(String(localized: "Cancel", table: "GitPlugin"), role: .cancel) {}
            Button(String(localized: "Create", table: "GitPlugin")) {
                let branchName = createBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !branchName.isEmpty else { return }
                Task { await createBranch(named: branchName) }
                createBranchName = ""
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            TextField("Search branches...", text: $branchSearch)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
            Spacer()
            Button {
                Task { await refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            Button {
                showCreateBranchAlert = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
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
                Text(String(localized: "Branches", table: "GitPlugin"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                branchList
                Divider().padding(.vertical, 4)
                Text(String(localized: "Commit History", table: "GitPlugin"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
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
                            .font(.system(size: 11))
                            .foregroundColor(branch.isCurrent ? Color(hex: "7C6FFF") : .secondary)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(branch.name)
                                .font(.system(size: 12, weight: branch.isCurrent ? .semibold : .regular))
                                .foregroundColor(.primary)
                            if !branch.latestCommitMessage.isEmpty {
                                Text(branch.latestCommitMessage)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(branch.isCurrent ? Color(hex: "7C6FFF").opacity(0.12) : Color.clear)
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
                        .foregroundColor(uncommittedFiles.isEmpty ? .green : .orange)
                    Text(uncommittedFiles.isEmpty ? "Clean working tree" : "Working state (\(uncommittedFiles.count))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)

            Divider()
            ForEach(commits, id: \.hash) { commit in
                GitCommitListRow(
                    commit: commit,
                    isSelected: selectedCommitHash == commit.hash,
                    style: .compact,
                    action: {
                        selectedCommitHash = commit.hash
                    }
                )
                Divider()
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    HStack(spacing: 10) {
                        Text(detail.author)
                        Text(shortDate(detail.date))
                        Text(String(detail.hash.prefix(7)))
                            .font(.system(.body, design: .monospaced))
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                Divider()
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
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            branches = []
            commits = []
            uncommittedFiles = []
            selectedCommitHash = nil
            selectedFile = nil
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
            branches = loadedBranchItems.map {
                GitBranch(id: $0.name, name: $0.name, isCurrent: $0.isCurrent, upstream: nil, latestCommitHash: "", latestCommitMessage: $0.message)
            }
            commits = loadedCommits
            uncommittedFiles = loadedFiles
            if selectedCommitHash == nil {
                selectedFile = loadedFiles.first?.path
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        loading = false
    }

    private func loadDetail(for hash: String?) async {
        guard let hash else {
            selectedFile = uncommittedFiles.first?.path
            commitDetail = nil
            commitChangedFiles = []
            return
        }
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return }

        loadingDetail = true
        do {
            let detail = try await GitService.shared.getCommitDetail(path: path, hash: hash)
            let files = try GitService.shared.getCommitChangedFiles(path: path, hash: hash)
            commitDetail = detail
            commitChangedFiles = files
            selectedFile = files.first?.path
        } catch {
            errorMessage = error.localizedDescription
        }
        loadingDetail = false
    }

    private func loadDiff(for file: String?) async {
        guard let file else { return }
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return }

        loadingDiff = true
        do {
            if let selectedCommitHash {
                let values = try await GitService.shared.getCommitFileContentChange(path: path, hash: selectedCommitHash, file: file)
                oldText = values.before ?? ""
                newText = values.after ?? ""
            } else {
                let values = try await GitService.shared.getUncommittedFileContentChange(path: path, file: file)
                oldText = values.before ?? ""
                newText = values.after ?? ""
            }
        } catch {
            oldText = ""
            newText = ""
            errorMessage = error.localizedDescription
        }
        loadingDiff = false
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
        actionMessage = "Creating branch \(name)..."
        do {
            try GitBranchService.createBranch(name, at: path)
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
