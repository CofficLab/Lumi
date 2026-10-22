import LumiUI
import ProviderGit
import SwiftUI

/// 分支弹层：列出可切换的分支，并提供新建分支入口。
struct GitBranchPopoverView: View {
    @ObservedObject var viewModel: GitBranchToolbarViewModel
    @State private var isCreatingBranch = false
    @State private var newBranchName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 280)
        .frame(minHeight: 200, maxHeight: 420)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)

            Text(pluginLocalization.string("Branches"))
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if viewModel.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage {
            errorBanner(errorMessage)
        }

        if viewModel.branches.isEmpty {
            AppEmptyState(
                icon: "arrow.triangle.branch",
                title: pluginLocalization.string("No Branches"),
                description: pluginLocalization.string("This repository has no branches yet.")
            )
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.branches) { branch in
                        GitBranchRow(
                            branch: branch,
                            isCurrent: branch.name == viewModel.currentBranch,
                            isEnabled: !viewModel.isBusy,
                            action: { Task { await viewModel.switchBranch(to: branch) } }
                        )
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 240)
        }

        Divider()
        createSection
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .semibold))
            Text(message)
                .font(.system(size: 11))
                .lineLimit(2)
            Spacer(minLength: 4)
            Button {
                viewModel.dismissError()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(pluginLocalization.string("Dismiss"))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 新建分支

    @ViewBuilder
    private var createSection: some View {
        if isCreatingBranch {
            VStack(spacing: 8) {
                AppInputField(
                    LocalizedStringKey(pluginLocalization.string("New Branch")),
                    text: $newBranchName
                )

                HStack(spacing: 8) {
                    Button(pluginLocalization.string("Cancel")) {
                        isCreatingBranch = false
                        newBranchName = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    AppButton(
                        pluginLocalization.string("Create"),
                        systemImage: "plus",
                        size: .small
                    ) {
                        let name = newBranchName
                        isCreatingBranch = false
                        newBranchName = ""
                        Task { await viewModel.createBranch(named: name) }
                    }
                    .disabled(
                        newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || viewModel.isBusy
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        } else {
            HStack(spacing: 6) {
                Button {
                    isCreatingBranch = true
                } label: {
                    Label(pluginLocalization.string("New Branch"), systemImage: "plus.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}
