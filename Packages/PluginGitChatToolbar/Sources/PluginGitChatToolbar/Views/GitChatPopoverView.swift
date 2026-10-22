import Foundation
import LumiUI
import ProviderGit
import SwiftUI

/// Chat Toolbar 弹层：分段控件切换「改动」与「提交历史」两个列表。
///
/// - Changes 段：工作区状态摘要（分支徽标 + 仓库路径）+ 变更文件列表
///   （`status.workingChanges()`），点击文件以预览方式切到该文件。
/// - Commits 段：最近提交列表；选中 commit 后下方展开该 commit 的变更文件。
///
/// 宽度 520，最大高度 480，与 `SkillChatToolbarView` 风格一致。
struct GitChatPopoverView: View {
    @LumiTheme private var theme
    @ObservedObject var viewModel: GitChatToolbarViewModel

    @State private var segment: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 520)
        .frame(minHeight: 240, maxHeight: 480)
        .background(theme.surface)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.primary)

            Text(pluginLocalization.string("Git Changes"))
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            AppSegmentedControl(
                [segmentTitle(0), segmentTitle(1)],
                selection: $segment,
                maxWidth: 200
            )

            Button {
                viewModel.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .help(pluginLocalization.string("Refresh"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func segmentTitle(_ index: Int) -> String {
        switch index {
        case 0: return "\(pluginLocalization.string("Changes")) (\(viewModel.workingChanges.count))"
        case 1: return "\(pluginLocalization.string("Commits")) (\(viewModel.commits.count))"
        default: return ""
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage, viewModel.workingChanges.isEmpty && viewModel.commits.isEmpty {
            GitChatErrorBanner(message: errorMessage)
        } else if segment == 0 {
            changesSection
        } else {
            commitsSection
        }
    }

    @ViewBuilder
    private var changesSection: some View {
        if viewModel.isLoading && viewModel.workingChanges.isEmpty {
            GitChatSkeletonView()
        } else if viewModel.workingChanges.isEmpty {
            GitChatEmptyState(
                icon: "checkmark.circle",
                title: pluginLocalization.string("No Changes"),
                description: pluginLocalization.string("The working tree is clean.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    GitWorkingStateHeader(
                        branch: viewModel.branchName,
                        repositoryPath: viewModel.repositoryPath
                    )
                    AppDivider()
                    ForEach(viewModel.workingChanges) { change in
                        GitWorkingChangeRow(change: change) {
                            viewModel.previewWorkingChange(path: change.path)
                        }
                        AppDivider()
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Commits

    @ViewBuilder
    private var commitsSection: some View {
        if viewModel.isLoading && viewModel.commits.isEmpty {
            GitChatSkeletonView()
        } else if viewModel.commits.isEmpty {
            GitChatEmptyState(
                icon: "clock",
                title: pluginLocalization.string("No Commits"),
                description: pluginLocalization.string("This repository has no commits yet.")
            )
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.commits, id: \.hash) { commit in
                            GitCommitRow(
                                commit: commit,
                                isSelected: viewModel.selectedCommitHash == commit.hash,
                                onTap: { viewModel.selectCommit(hash: commit.hash) }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: viewModel.selectedCommitHash == nil ? .infinity : 240)

                if viewModel.selectedCommitHash != nil {
                    Divider()
                    selectedCommitChangesSection
                }
            }
        }
    }

    private var selectedCommitChangesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if viewModel.isLoadingCommitChanges {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.primary)
                }
                Text(String(viewModel.selectedCommitHash?.prefix(7) ?? ""))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text("· \(viewModel.selectedCommitChanges.count) \(pluginLocalization.string("files"))")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button {
                    viewModel.clearCommitSelection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if viewModel.selectedCommitChanges.isEmpty && !viewModel.isLoadingCommitChanges {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.selectedCommitChanges) { change in
                            GitCommitChangeRow(change: change) {
                                viewModel.previewWorkingChange(path: change.path)
                            }
                            AppDivider()
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
