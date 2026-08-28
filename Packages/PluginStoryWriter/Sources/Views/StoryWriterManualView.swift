import LumiUI
import SwiftUI

// MARK: - Manual View

/// 故事创作使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct StoryWriterManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Story Writer"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of Story Writer: creating and importing stories, writing chapters, and exporting them as Markdown."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Sidebar: the Story Outline rail with the story picker, the + button for a new story, the import button for Markdown files, and the chapter tree.")),
                .init(L("Story view: shows the story title, the last-edited time, a synopsis editor, statistics, and the Export and Delete buttons. Double-click the title to rename the story.")),
                .init(L("Chapter view: provides the chapter title, a writing area, and a footer with word count and target.")),
                .init(L("When no story is selected, an empty-state hint is shown in the main pane.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Story Writer tab in the sidebar.")),
                .init(L("Click + to create a story and enter its title, or click the import button to import a Markdown file as a chapter.")),
                .init(L("Add chapters in the chapter tree and select a chapter to write.")),
                .init(L("Ask the AI in the chat to continue or polish the current chapter.")),
                .init(L("Open the story view to review the synopsis and the statistics.")),
                .init(L("Click Export to save the story as a Markdown file.")),
            ])

            ManualSectionHeader(number: 4, title: L("AI Writing"))
            ManualBulletList(items: [
                .init(L("Ask the AI to write, continue, or polish a chapter.")),
                .init(L("Ask the AI to import Markdown files or export the story as Markdown.")),
            ])

            ManualSectionHeader(number: 5, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Save your work regularly while writing.")),
                .init(L("The word-count target is for reference only.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 侧边栏:故事选择器 + 工具按钮 + 章节树
                    VStack(alignment: .leading, spacing: 7) {
                        storyPickerMock()

                        HStack(spacing: 5) {
                            toolbarPill("plus")
                            toolbarPill("square.and.arrow.down")
                        }

                        groupLabel(L("Chapters"))
                        chapterRowMock(indent: 0)
                        chapterRowMock(indent: 1)
                        chapterRowMock(indent: 1)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 132, height: 168, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    // ② 主区域:章节编辑区
                    VStack(alignment: .leading, spacing: 9) {
                        lineMock(width: 96)

                        VStack(alignment: .leading, spacing: 6) {
                            lineMock(width: 150)
                            lineMock(width: 132)
                            lineMock(width: 140)
                            lineMock(width: 88)
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: 6) {
                            lineMock(width: 30)
                            lineMock(width: 18)
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 168, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Outline sidebar"))
                    ManualFigureLegendItem(2, L("Chapter editor"))
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

    /// 故事选择器示意:下拉框样式。
    private func storyPickerMock() -> some View {
        HStack(spacing: 5) {
            lineMock(width: 46)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 7))
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 章节树行示意:折叠箭头 + 两根文字线。
    private func chapterRowMock(indent: CGFloat) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.right")
                .font(.system(size: 7))
                .foregroundStyle(theme.textSecondary)
            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 44)
                lineMock(width: 26)
            }
        }
        .padding(4)
        .padding(.leading, indent * 12)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
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
        LumiPluginLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        StoryWriterManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
