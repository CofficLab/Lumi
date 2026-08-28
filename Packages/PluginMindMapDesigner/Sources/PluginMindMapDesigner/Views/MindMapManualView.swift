import LumiUI
import SwiftUI

// MARK: - Manual View

/// 思维导图使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `DocsViewProviding.addManual` 暴露,在 设置 → 通用 → 说明书 中阅读。
public struct MindMapManualView: View {
    @LumiTheme private var theme

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Mind Map"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of Mind Map: creating, editing, and organizing mind maps on a canvas."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Top bar: the scope picker (In Project / In App), the map picker, New, the delete button, and the zoom controls.")),
                .init(L("Canvas: shows the nodes of the current mind map; click a node to select it, and click it again to edit its text inline.")),
                .init(L("Node action bar: appears at the bottom when a node is selected, with Child, Sibling, Expand / Collapse, and Delete.")),
                .init(L("Rail Mind Maps: the scope picker, the document list (each row shows its node count), and the New button.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Mind Map tab in the sidebar.")),
                .init(L("Click New to create an empty mind map, or ask the agent in chat, e.g. \"create a mind map about Swift concurrency\".")),
                .init(L("Click a node to select it; click it again and type to replace the text.")),
                .init(L("Use Child and Sibling in the node action bar to add a child node or a sibling node.")),
                .init(L("Use Expand / Collapse to show or hide a node's children, and the zoom controls to zoom the canvas.")),
                .init(L("Use Delete to remove the selected node; use the trash button in the top bar to delete the whole map.")),
            ])

            ManualSectionHeader(number: 4, title: L("What to Ask the AI"))
            ManualBulletList(items: [
                .init(L("Create a mind map from a topic in the conversation.")),
                .init(L("Import an outline, such as a Markdown list, into a mind map.")),
                .init(L("Edit nodes and export the current mind map.")),
            ])

            ManualSectionHeader(number: 5, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Documents are grouped by scope: In Project maps are stored with the current project, and In App maps are available in every project.")),
                .init(L("The root node cannot be deleted; delete the whole map from the top bar or the rail list instead.")),
                .init(L("With no mind map, the canvas shows an empty state with a create button.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 顶栏示意
                HStack(spacing: 6) {
                    segmentedMock()
                    mapPickerMock()
                    Spacer(minLength: 0)
                    toolbarPill("plus")
                    toolbarPill("trash")
                    toolbarPill("plus.magnifyingglass")
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 画布示意:中心节点 + 分支
                ZStack {
                    nodeMock(width: 56, filled: true)
                    nodeMock(width: 40, filled: false)
                        .offset(x: 88, y: -18)
                    nodeMock(width: 34, filled: false)
                        .offset(x: 72, y: 26)
                    nodeMock(width: 40, filled: false)
                        .offset(x: -86, y: 12)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .frame(height: 108)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                // ③ 节点操作条示意
                HStack(spacing: 8) {
                    toolbarPill("plus.circle")
                    toolbarPill("arrow.down.right.circle")
                    toolbarPill("chevron.down.circle")
                    toolbarPill("minus.circle")
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Top bar"))
                    ManualFigureLegendItem(2, L("Canvas"))
                    ManualFigureLegendItem(3, L("Node action bar"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 节点示意:圆角块 + 文字线。
    private func nodeMock(width: CGFloat, filled: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(filled ? theme.primary.opacity(0.7) : Color.primary.opacity(0.15))
                .frame(width: 5, height: 5)
            lineMock(width: width - 8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(filled ? theme.primary.opacity(0.12) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(filled ? theme.primary.opacity(0.5) : theme.appDivider)
        )
    }

    /// 作用域切换示意:两格相连的分段控件。
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

    /// 导图选择器示意。
    private func mapPickerMock() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary)
            lineMock(width: 34)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 6))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
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

    /// 示意图中的占位文字线。
    private func lineMock(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 3)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        MindMapLocalization.string(key)
    }
}
