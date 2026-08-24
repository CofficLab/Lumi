import LumiUI
import SwiftUI

// MARK: - Manual View

/// Git 使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct GitManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Git"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Git panel: viewing the commit history, inspecting changes, and committing."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("History sidebar: the current status (clean working tree or the number of uncommitted files) followed by the commit list with relative dates.")),
                .init(L("Detail area: shows the working state, the repository stats (Total Commits, Contributors, Latest Commit), and the diff of the selected commit.")),
                .init(L("Commit input: the message field with the AI button, which generates a commit message, and the Commit button.")),
                .init(L("Tools tab: a segmented switch with six tools, including Stash and .gitignore.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("View the commit history in the History sidebar; the current working state is shown at the top.")),
                .init(L("Select a commit to view its changes in the diff.")),
                .init(L("Enter a commit message in the field; click AI to generate one automatically.")),
                .init(L("Click Commit to commit the current changes.")),
            ])

            ManualSectionHeader(number: 4, title: L("Tools"))
            ManualBulletList(items: [
                .init(L("Stash: save and restore uncommitted changes.")),
                .init(L(".gitignore: view and edit the ignore rules of the repository.")),
                .init(L("LFS: manage the large file storage of the repository.")),
                .init(L("Submodule: view and manage the submodules of the repository.")),
                .init(L("Conflicts: inspect and resolve merge conflicts.")),
                .init(L("Auto Push: push commits automatically after committing.")),
            ])

            ManualSectionHeader(number: 5, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("A project must be open; the Git tabs are hidden when no project is open.")),
                .init(L("The AI button requires a configured language model.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 历史侧栏:状态卡 + 提交列表
                    VStack(alignment: .leading, spacing: 7) {
                        groupLabel(L("History"))
                        statusCardMock()
                        commitRowMock(selected: true)
                        commitRowMock()
                        commitRowMock()
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 132, height: 184, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    VStack(spacing: 0) {
                        // ② 详情区:工作状态 + 统计 + 差异
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                statusDotMock()
                                lineMock(width: 44)
                                Spacer(minLength: 0)
                                lineMock(width: 18)
                                lineMock(width: 18)
                            }

                            HStack(spacing: 5) {
                                diffLineMock(width: 66, kind: .add)
                                Spacer(minLength: 0)
                            }
                            HStack(spacing: 5) {
                                diffLineMock(width: 52, kind: .del)
                                Spacer(minLength: 0)
                            }
                            HStack(spacing: 5) {
                                diffLineMock(width: 74, kind: .plain)
                                Spacer(minLength: 0)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                        Divider()

                        // ③ 提交输入:信息框 + AI 与提交按钮
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(theme.appDivider)
                                .frame(width: 84, height: 16)
                            toolbarPill("sparkles")
                            toolbarPill("checkmark.circle.fill")
                        }
                        .padding(8)
                        .overlay(alignment: .bottomLeading) { ManualFigureMarker(3).offset(y: 9) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 184)
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("History sidebar"))
                    ManualFigureLegendItem(2, L("Detail area"))
                    ManualFigureLegendItem(3, L("Commit input"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 侧边栏分组小标题。
    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(theme.textSecondary)
    }

    /// 状态卡示意:状态点 + 两根文字线。
    private func statusCardMock() -> some View {
        HStack(spacing: 6) {
            statusDotMock()
            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 52)
                lineMock(width: 34)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 提交行示意:哈希 + 两根文字线。
    private func commitRowMock(selected: Bool = false) -> some View {
        HStack(spacing: 6) {
            lineMock(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 56)
                lineMock(width: 28)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(selected ? Color.primary.opacity(0.08) : Color.clear)
        )
    }

    /// 差异行示意:按类型着色的占位行。
    private enum DiffKind { case add, del, plain }

    private func diffLineMock(width: CGFloat, kind: DiffKind) -> some View {
        HStack(spacing: 5) {
            Text(kind == .add ? "+" : kind == .del ? "-" : " ")
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(theme.textTertiary)
                .frame(width: 6, alignment: .trailing)
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    kind == .add
                        ? theme.success.opacity(0.35)
                        : kind == .del
                            ? theme.error.opacity(0.35)
                            : Color.primary.opacity(0.14)
                )
                .frame(width: width, height: 3)
        }
    }

    /// 状态点示意。
    private func statusDotMock() -> some View {
        Circle()
            .fill(theme.success.opacity(0.8))
            .frame(width: 6, height: 6)
    }

    /// 工具栏按钮示意。
    private func toolbarPill(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 9))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 示意图中的占位文字线。
    private func lineMock(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 3)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#if DEBUG
#Preview {
    ScrollView {
        GitManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
#endif
