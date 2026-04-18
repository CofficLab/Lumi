import SwiftUI
import MagicKit

/// Git 分支切换面板
struct GitBranchPickerPanel: View {
    @EnvironmentObject private var projectVM: ProjectVM

    @State private var localBranches: [GitBranch] = []
    @State private var remoteBranches: [GitBranch] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var isForceCheckout = false
    @State private var showRemoteBranches = false
    @State private var performingAction: String?

    @State private var showCreateBranchAlert = false
    @State private var createBranchName = ""

    // MARK: - Filtered Data

    var filteredLocalBranches: [GitBranch] {
        guard !searchText.isEmpty else { return localBranches }
        return localBranches.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredRemoteBranches: [GitBranch] {
        guard !searchText.isEmpty else { return remoteBranches }
        return remoteBranches.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else {
                contentSection
            }

            Divider()
            footerSection
        }
        .frame(width: 320)
        .task { await loadBranches() }
        .alert(isPresented: $showCreateBranchAlert) {
            createBranchAlert
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text(String(localized: "Switch Branch", table: "GitBranchStatusBar"))
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                if !isLoading {
                    Button(action: { Task { await loadBranches() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Refresh", table: "GitBranchStatusBar"))
                }
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                TextField(String(localized: "Search branches…", table: "GitBranchStatusBar"), text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Color.basePalette.surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    // MARK: - Content

    private var contentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                branchSectionHeader(
                    title: String(localized: "Local Branches", table: "GitBranchStatusBar"),
                    count: localBranches.count
                )

                if filteredLocalBranches.isEmpty {
                    emptyStateView(icon: "folder", message: String(localized: "No branches found", table: "GitBranchStatusBar"))
                } else {
                    VStack(spacing: 2) {
                        ForEach(filteredLocalBranches) { branch in
                            branchRow(branch: branch)
                        }
                    }
                }

                if !remoteBranches.isEmpty {
                    Divider().padding(.vertical, DesignTokens.Spacing.xs)

                    branchSectionHeader(
                        title: String(localized: "Remote Branches", table: "GitBranchStatusBar"),
                        count: remoteBranches.count,
                        isCollapsible: true
                    )

                    if showRemoteBranches {
                        if filteredRemoteBranches.isEmpty {
                            emptyStateView(icon: "globe", message: String(localized: "No remote branches found", table: "GitBranchStatusBar"))
                        } else {
                            VStack(spacing: 2) {
                                ForEach(filteredRemoteBranches) { branch in
                                    remoteBranchRow(branch: branch)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.bottom, DesignTokens.Spacing.md)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Button(action: { showCreateBranchAlert = true }) {
                Label(String(localized: "New Branch", table: "GitBranchStatusBar"), systemImage: "plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)

            Spacer()

            if let performingAction {
                Text(performingAction)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Color.basePalette.surfaceBackground)
    }

    // MARK: - Subviews

    private func branchSectionHeader(title: String, count: Int, isCollapsible: Bool = false) -> some View {
        HStack {
            Text("\(title) (\(count))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .textCase(.uppercase)

            Spacer()

            if isCollapsible {
                Button(action: { showRemoteBranches.toggle() }) {
                    Image(systemName: showRemoteBranches ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, DesignTokens.Spacing.xs)
    }

    private func branchRow(branch: GitBranch) -> some View {
        Button(action: {
            if !branch.isCurrent {
                Task { await performCheckout(branch: branch.name) }
            }
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if branch.isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.primary)
                        .frame(width: 16)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.name)
                        .font(.system(size: 13, weight: branch.isCurrent ? .medium : .regular))
                        .foregroundColor(branch.isCurrent
                            ? DesignTokens.Color.semantic.primary
                            : DesignTokens.Color.semantic.textPrimary)

                    if let subject = branch.lastCommitSubject {
                        Text(subject)
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let date = branch.lastCommitDate {
                    Text(date.relativeFormat)
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(branch.isCurrent ? DesignTokens.Color.semantic.primary.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        }
        .buttonStyle(.plain)
        .disabled(performingAction != nil)
    }

    private func remoteBranchRow(branch: GitBranch) -> some View {
        Button(action: {
            Task { await performRemoteCheckout(branch: branch.name) }
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.info)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.displayName)
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    if let remoteName = branch.remoteName {
                        Text(remoteName)
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }
                }

                Spacer()

                if let subject = branch.lastCommitSubject {
                    Text(subject)
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        }
        .buttonStyle(.plain)
        .help(String(localized: "Checkout as tracking branch", table: "GitBranchStatusBar"))
        .disabled(performingAction != nil)
    }

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView().scaleEffect(0.8)
            Text(String(localized: "Loading branches…", table: "GitBranchStatusBar"))
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Color.semantic.warning)

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)

            Button(action: { Task { await loadBranches() } }) {
                Text(String(localized: "Retry", table: "GitBranchStatusBar"))
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    private func emptyStateView(icon: String, message: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.sm)
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

    /// Result types for detached tasks
    private struct BranchLoadResult {
        let branches: [GitBranch]
        let remote: [GitBranch]
        let error: String?
    }

    private struct ActionResult {
        let error: String?
    }

    private func loadBranches() async {
        isLoading = true
        errorMessage = nil

        let path = projectVM.currentProjectPath

        let result: BranchLoadResult = await Task.detached {
            guard !path.isEmpty else {
                return BranchLoadResult(branches: [], remote: [], error: String(localized: "No project path", table: "GitBranchStatusBar"))
            }

            let branches = GitBranchService.listLocalBranches(at: path)
            let remote = GitBranchService.listRemoteBranches(at: path)
            return BranchLoadResult(branches: branches, remote: remote, error: nil)
        }.value

        await MainActor.run {
            isLoading = false
            if let error = result.error {
                errorMessage = error
            } else {
                localBranches = result.branches.sorted { a, b in
                    if a.isCurrent { return true }
                    if b.isCurrent { return false }
                    return a.name < b.name
                }
                remoteBranches = result.remote.sorted { $0.name < $1.name }
            }
        }
    }

    private func performCheckout(branch: String) async {
        let path = projectVM.currentProjectPath
        performingAction = String(localized: "Switching to \(branch)…", table: "GitBranchStatusBar")
        errorMessage = nil

        let result: ActionResult = await Task.detached {
            do {
                try GitBranchService.checkout(branch: branch, at: path, force: false)
                return ActionResult(error: nil)
            } catch {
                return ActionResult(error: error.localizedDescription)
            }
        }.value

        await MainActor.run {
            performingAction = nil
            if let error = result.error {
                if error.contains("stash") || error.contains("commit") || error.contains("uncommitted") {
                    isForceCheckout = true
                    errorMessage = String(localized: "Uncommitted changes. Force checkout?", table: "GitBranchStatusBar")
                } else {
                    errorMessage = error
                }
            } else {
                Task { await loadBranches() }
            }
        }
    }

    private func performRemoteCheckout(branch: String) async {
        let path = projectVM.currentProjectPath
        performingAction = String(localized: "Creating tracking branch…", table: "GitBranchStatusBar")
        errorMessage = nil

        let result: ActionResult = await Task.detached {
            do {
                try GitBranchService.checkoutRemoteBranch(branch, at: path)
                return ActionResult(error: nil)
            } catch {
                return ActionResult(error: error.localizedDescription)
            }
        }.value

        await MainActor.run {
            performingAction = nil
            if let error = result.error {
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

        let result: ActionResult = await Task.detached {
            do {
                try GitBranchService.createBranch(name, at: path)
                return ActionResult(error: nil)
            } catch {
                return ActionResult(error: error.localizedDescription)
            }
        }.value

        await MainActor.run {
            performingAction = nil
            if let error = result.error {
                errorMessage = error
            } else {
                Task { await loadBranches() }
            }
        }
    }
}

// MARK: - Date Extension

private extension Date {
    var relativeFormat: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview("Branch Picker Panel") {
    GitBranchPickerPanel()
        .inRootView()
}
