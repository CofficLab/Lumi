import SwiftUI
import MagicKit
import LibGit2Swift

/// Git 分支切换面板
struct GitBranchPickerPanel: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @Environment(\.colorScheme) private var colorScheme

    @State private var branches: [GitBranch] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var performingAction: String?

    @State private var showCreateBranchAlert = false
    @State private var createBranchName = ""

    // MARK: - Commit

    @State private var showCommitPanel = false
    @State private var commitLanguage: GitCommitService.Language = .english
    @State private var isCommitting = false
    @State private var commitResult: GitCommitService.Result?
    @State private var commitError: String?

    // MARK: - Computed

    /// 当前分支
    private var currentBranch: GitBranch? {
        branches.first { $0.isCurrent }
    }

    /// 非当前分支（搜索过滤后）
    private var filteredBranches: [GitBranch] {
        let others = branches.filter { !$0.isCurrent }
        guard !searchText.isEmpty else { return others }
        return others.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// 是否有未提交的更改
    private var hasUncommittedChanges: Bool {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return false }
        return GitBranchService.isWorkingTreeDirty(at: path)
    }

    // MARK: - Adaptive Colors

    private var currentBranchBackground: Color {
        colorScheme == .light
            ? Color(hex: "7C6FFF").opacity(0.08)
            : Color(hex: "7C6FFF").opacity(0.15)
    }

    private var footerBackground: Color {
        colorScheme == .light
            ? Color(hex: "F5F5F7")
            : Color(hex: "0D0D12")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            // Commit 区域
            if hasUncommittedChanges {
                commitSection
            }

            if isLoading {
                Divider()
                loadingView
            } else if let error = errorMessage {
                Divider()
                errorView(message: error)
            } else {
                contentSection
            }

            if let action = performingAction {
                Divider()
                actionFooterView(message: action)
            }
        }
        .task { await loadBranches() }
        .alert(isPresented: $showCreateBranchAlert) {
            createBranchAlert
        }
        .frame(height: 500)
    }

    // MARK: - Commit Section

    private var commitSection: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "7C6FFF"))

                    Text("AI Commit")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                    Spacer()
                }

                HStack(spacing: 8) {
                    commitButton(
                        title: "EN Commit",
                        icon: "🇬🇧",
                        language: .english
                    )

                    commitButton(
                        title: "CN Commit",
                        icon: "🇨🇳",
                        language: .chinese
                    )
                }

                // 状态展示
                if isCommitting {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("正在生成并提交...")
                            .font(.system(size: 11))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                } else if let result = commitResult {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "30D158"))
                        Text("已提交: \(result.message)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "30D158"))
                            .lineLimit(1)
                    }
                } else if let error = commitError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(Color(hex: "FF9F0A"))
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "FF9F0A"))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func commitButton(title: String, icon: String, language: GitCommitService.Language) -> some View {
        Button(action: {
            commitLanguage = language
            Task { await executeCommit(language: language) }
        }) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "7C6FFF").opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .disabled(isCommitting)
        .frame(maxWidth: .infinity)
    }

    private func executeCommit(language: GitCommitService.Language) async {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return }

        isCommitting = true
        commitResult = nil
        commitError = nil

        do {
            // 1. 收集变更
            let changes = try await GitCommitService.gatherChanges(at: path)

            // 2. 生成 commit message
            let config = RootViewContainer.shared.agentSessionConfig.getCurrentConfig()
            let message = try await GitCommitService.generateCommitMessage(
                changes: changes,
                language: language,
                llmService: RootViewContainer.shared.llmService,
                config: config
            )

            // 3. 执行 commit
            let hash = try GitCommitService.executeCommit(message: message, at: path)

            await MainActor.run {
                isCommitting = false
                commitResult = GitCommitService.Result(message: message, commitHash: hash)
                commitError = nil

                // 刷新分支列表
                Task { await loadBranches() }
            }
        } catch {
            let err = error as NSError
            if let ce = error as? GitCommitError {
                switch ce {
                case .noChanges:
                    await MainActor.run {
                        isCommitting = false
                        commitError = "没有需要提交的变更"
                    }
                case .commitFailed(let msg):
                    await MainActor.run {
                        isCommitting = false
                        commitError = "提交失败: \(msg)"
                    }
                case .emptyResponse:
                    await MainActor.run {
                        isCommitting = false
                        commitError = "AI 未返回有效内容"
                    }
                case .llmError(let msg):
                    await MainActor.run {
                        isCommitting = false
                        commitError = "AI 错误: \(msg)"
                    }
                default:
                    break
                }
            } else if let llmError = error as? LLMServiceError {
                await MainActor.run {
                    isCommitting = false
                    commitError = "AI 请求失败: \(llmError.localizedDescription)"
                }
            } else {
                await MainActor.run {
                    isCommitting = false
                    commitError = "Commit 失败: \(err.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            TextField(String(localized: "Search branches…", table: "GitBranchStatusBar"), text: $searchText)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 14)

            if !isLoading {
                Button(action: { Task { await loadBranches() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .buttonStyle(.plain)
                .help(String(localized: "Refresh", table: "GitBranchStatusBar"))

                Button(action: { showCreateBranchAlert = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .buttonStyle(.plain)
                .help(String(localized: "New Branch", table: "GitBranchStatusBar"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    private var contentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // 当前分支
                if let current = currentBranch {
                    Text(String(localized: "Current Branch", table: "GitBranchStatusBar"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                    currentBranchRow(branch: current)
                        .padding(.bottom, 8)
                }

                // 其他分支
                if !filteredBranches.isEmpty {
                    Divider().padding(.vertical, 4)

                    Text(String(localized: "Other Branches", table: "GitBranchStatusBar"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                    VStack(spacing: 2) {
                        ForEach(filteredBranches) { branch in
                            branchRow(branch: branch)
                        }
                    }
                }

                if currentBranch == nil && filteredBranches.isEmpty {
                    emptyStateView(icon: "folder", message: String(localized: "No branches found", table: "GitBranchStatusBar"))
                }
            }
        }
    }

    // MARK: - Footer

    /// 操作状态栏：仅在切换/创建分支时显示，空闲时隐藏
    private func actionFooterView(message: String) -> some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            Spacer()
        }
        .background(footerBackground)
    }

    // MARK: - Subviews

    /// 当前分支行（不可点击）
    private func currentBranchRow(branch: GitBranch) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "7C6FFF"))
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(branch.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "7C6FFF"))
                    .lineLimit(1)

                if !branch.latestCommitMessage.isEmpty {
                    Text(branch.latestCommitMessage)
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(currentBranchBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// 可切换分支行
    private func branchRow(branch: GitBranch) -> some View {
        Button(action: {
            Task { await performCheckout(branch: branch.name) }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "98989E"))
                    .frame(width: 16, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.name)
                        .font(.system(size: 13))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        .lineLimit(1)

                    if !branch.latestCommitMessage.isEmpty {
                        Text(branch.latestCommitMessage)
                            .font(.system(size: 11))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(performingAction != nil)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(0.8)
            Text(String(localized: "Loading branches…", table: "GitBranchStatusBar"))
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "FF9F0A"))

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button(action: { Task { await loadBranches() } }) {
                Text(String(localized: "Retry", table: "GitBranchStatusBar"))
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func emptyStateView(icon: String, message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "98989E"))
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "98989E"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var createBranchAlert: Alert {
        Alert(
            title: Text(String(localized: "Create New Branch", table: "GitBranchStatusBar")),
            message: Text(String(localized: "Enter a name for the new branch:", table: "GitBranchStatusBar")),
            primaryButton: .default(Text(String(localized: "Create", table: "GitBranchStatusBar"))) {
                guard !createBranchName.isEmpty else { return }
                let branchName = createBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                createBranchName = ""
                Task { await performCreateBranch(name: branchName) }
            },
            secondaryButton: .cancel()
        )
    }

    // MARK: - Actions

    private func loadBranches() async {
        isLoading = true
        errorMessage = nil

        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            isLoading = false
            return
        }

        let branchNames: [(name: String, isCurrent: Bool, message: String)] = await Task.detached {
            let branches = GitBranchService.listLocalBranches(at: path)
            return branches.map { (name: $0.name, isCurrent: $0.isCurrent, message: $0.latestCommitMessage) }
        }.value

        let branches = branchNames.map { info -> GitBranch in
            GitBranch(
                id: info.name,
                name: info.name,
                isCurrent: info.isCurrent,
                upstream: nil,
                latestCommitHash: "",
                latestCommitMessage: info.message
            )
        }

        isLoading = false
        if branches.isEmpty {
            errorMessage = String(localized: "No branches found", table: "GitBranchStatusBar")
        } else {
            self.branches = branches
        }
    }

    private func performCheckout(branch: String) async {
        let path = projectVM.currentProjectPath
        performingAction = String(localized: "Switching to \(branch)…", table: "GitBranchStatusBar")
        errorMessage = nil

        let error: String? = await Task.detached {
            do {
                try GitBranchService.checkout(branch: branch, at: path)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value

        await MainActor.run {
            performingAction = nil
            if let error {
                errorMessage = error
            } else {
                Task { await loadBranches() }
            }
        }
    }

    private func performCreateBranch(name: String) async {
        let path = projectVM.currentProjectPath
        performingAction = String(localized: "Creating branch \(name)…", table: "GitBranchStatusBar")
        errorMessage = nil

        let error: String? = await Task.detached {
            do {
                try GitBranchService.createBranch(name, at: path)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value

        await MainActor.run {
            performingAction = nil
            if let error {
                errorMessage = error
            } else {
                Task { await loadBranches() }
            }
        }
    }
}

// MARK: - Preview

#Preview("Branch Picker Panel") {
    GitBranchPickerPanel()
        .inRootView()
}
