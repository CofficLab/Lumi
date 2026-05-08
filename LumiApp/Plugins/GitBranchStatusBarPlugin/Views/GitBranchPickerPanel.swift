import MagicDiffView
import MagicKit
import SwiftUI

/// Git 状态栏弹出面板（独立实现，不依赖 GitCommitHistoryPlugin）
struct GitPluginPopoverView: View {
    @EnvironmentObject private var projectVM: ProjectVM
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
    @State private var commitMessage = ""
    @State private var isGenerating = false
    @State private var isCommitting = false
    @State private var resultMessage: String?
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
            Button("Cancel", role: .cancel) {}
            Button("Create") {
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
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                TextEditor(text: $commitMessage)
                    .font(.system(size: 12))
                    .frame(minHeight: 42, maxHeight: 76)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                VStack(spacing: 6) {
                    Button {
                        Task { await generateAICommitMessage() }
                    } label: {
                        HStack(spacing: 4) {
                            if isGenerating {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text("AI")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isGenerating || isCommitting)

                    Button {
                        Task { await commitNow() }
                    } label: {
                        HStack(spacing: 4) {
                            if isCommitting {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("Commit")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || isCommitting)
                }
                .frame(width: 100)
            }
            if let resultMessage {
                Text(resultMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var leftPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Branches")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                branchList
                Divider().padding(.vertical, 4)
                Text("Commit History")
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
                Button {
                    selectedCommitHash = commit.hash
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(selectedCommitHash == commit.hash ? Color(hex: "7C6FFF") : Color.secondary.opacity(0.5))
                            .frame(width: 7, height: 7)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(commit.message)
                                .font(.system(size: 11, weight: selectedCommitHash == commit.hash ? .semibold : .regular))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            Text("\(commit.author) · \(relativeTime(from: commit.date))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(String(commit.hash.prefix(7)))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                    .background(selectedCommitHash == commit.hash ? Color.accentColor.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }

    private var workingStateDetail: some View {
        HSplitView {
            List(uncommittedFiles, id: \.path, selection: $selectedFile) { file in
                HStack {
                    Text(file.path)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    Text(file.changeType.displayLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(file.changeType.color)
                }
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
                    HStack {
                        Text(file.path)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(file.changeType.displayLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(file.changeType.color)
                    }
                }
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)
                diffPanel
            }
        }
    }

    private var diffPanel: some View {
        VStack(spacing: 0) {
            if let selectedFile {
                HStack {
                    Text(selectedFile)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                Divider()
            }

            if loadingDiff {
                ProgressView("Loading diff...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedFile == nil {
                Text("Select a file to view diff")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if oldText.isEmpty && newText.isEmpty {
                Text("Cannot display diff for this file")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MagicDiffView(oldText: oldText, newText: newText, enableCollapsing: true, minUnchangedLines: 3)
            }
        }
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

        async let branchTask: [GitBranch] = Task.detached {
            let items = GitBranchService.listLocalBranches(at: path)
            return items.map {
                GitBranch(id: $0.name, name: $0.name, isCurrent: $0.isCurrent, upstream: nil, latestCommitHash: "", latestCommitMessage: $0.latestCommitMessage)
            }
        }.value

        async let commitTask = GitService.shared.getLog(path: path, count: commitPageSize, branch: nil, file: nil)
        async let fileTask = GitService.shared.getUncommittedChanges(path: path)

        do {
            let loadedBranches = await branchTask
            let loadedCommits = try await commitTask
            let loadedFiles = try await fileTask
            branches = loadedBranches
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

    private func generateAICommitMessage() async {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return }
        isGenerating = true
        resultMessage = nil
        do {
            let changes = try await GitCommitService.gatherChanges(at: path)
            let config = RootViewContainer.shared.agentSessionConfig.getCurrentConfig()
            let message = try await GitCommitService.generateCommitMessage(
                changes: changes,
                language: .english,
                llmService: RootViewContainer.shared.llmService,
                config: config
            )
            commitMessage = message
        } catch {
            resultMessage = error.localizedDescription
        }
        isGenerating = false
    }

    private func commitNow() async {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return }
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        isCommitting = true
        resultMessage = nil
        do {
            let hash = try GitCommitService.executeCommit(message: message, at: path)
            resultMessage = "Committed: \(hash)"
            commitMessage = ""
            await refreshAll()
        } catch {
            resultMessage = error.localizedDescription
        }
        isCommitting = false
    }

    private func relativeTime(from dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return shortDate(dateString)
        }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    private func shortDate(_ value: String) -> String {
        value.count >= 10 ? String(value.prefix(10)) : value
    }
}

#Preview("Git Plugin Popover") {
    GitPluginPopoverView()
        .inRootView()
}
