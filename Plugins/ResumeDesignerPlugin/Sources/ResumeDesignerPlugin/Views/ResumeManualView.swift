import LumiUI
import SwiftUI

// MARK: - Manual View

/// 简历设计器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct ResumeManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Resume Designer"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Resume Designer: asking the Agent to create resumes, previewing and editing them, and exporting or printing the result."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Resumes list: each resume with its title, paper size, and template; click to select, right-click to delete.")),
                .init(L("Toolbar: the Preview / Source switch, the paper size caption, and the Print, Export PDF, and Export PNG buttons.")),
                .init(L("Preview: shows the rendered page; clicking a block drafts an edit request in the chat.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Ask the Agent in the chat to create a resume, e.g. \"help me write a resume\".")),
                .init(L("Select a resume in the Resumes list to open it.")),
                .init(L("Switch between Preview and Source in the toolbar to view the page or the HTML source.")),
                .init(L("In Preview, click a block to draft an edit request for the Agent.")),
                .init(L("Click Export PDF or Export PNG and choose a folder, or click Print.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Resumes are stored in the plugin's storage inside the app.")),
                .init(L("Right-click a resume in the list to delete it.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 简历列表示意
                    VStack(alignment: .leading, spacing: 7) {
                        groupLabel(L("Resumes"))
                        resumeRowMock(selected: true)
                        resumeRowMock(selected: false)
                        resumeRowMock(selected: false)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 122, height: 158, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    // 主区域:② 工具栏 + ③ 预览
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            segmentedMock()
                            Spacer(minLength: 0)
                            toolbarPill("printer")
                            toolbarPill("doc.richtext")
                            toolbarPill("photo")
                        }
                        .overlay(alignment: .top) { ManualFigureMarker(2).offset(y: -9) }

                        Spacer(minLength: 0)

                        pageMock()

                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 158)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Resumes"))
                    ManualFigureLegendItem(2, L("Toolbar"))
                    ManualFigureLegendItem(3, L("Preview"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 列表小标题。
    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(theme.textSecondary)
    }

    /// 简历行示意:文档图标 + 标题和纸张·模板两行。
    private func resumeRowMock(selected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 8))
                .foregroundStyle(selected ? theme.primary : theme.textSecondary)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 44)
                lineMock(width: 30)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? theme.primary.opacity(0.1) : Color.primary.opacity(0.04))
        )
    }

    /// 「预览 / 源码」切换示意:两格相连的分段控件。
    private func segmentedMock() -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 20, height: 14)
            Rectangle().fill(Color.clear).frame(width: 20, height: 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 工具栏按钮示意。
    private func toolbarPill(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 9))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 简历页面示意:文档框 + 区块线,其中一个区块高亮表示可点选。
    private func pageMock() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            lineMock(width: 30)
            blockMock(highlighted: false)
            blockMock(highlighted: true)
            blockMock(highlighted: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 页面区块示意:两根文字线,高亮时带描边。
    private func blockMock(highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            lineMock(width: 56)
            lineMock(width: 40)
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(highlighted ? theme.warning.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(highlighted ? theme.warning : Color.clear, lineWidth: 1)
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
        ResumeLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        ResumeManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
