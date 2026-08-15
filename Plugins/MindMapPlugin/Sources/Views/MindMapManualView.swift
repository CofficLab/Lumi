import LumiUI
import SwiftUI

// MARK: - Manual View

/// 思维导图使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct MindMapManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Mind Map", "思维导图"),
                subtitle: L("User Manual", "使用手册")
            )

            ManualSectionHeader(number: 1, title: L("Overview", "概述"))
            Text(L(
                "This manual covers the interface and basic operations of Mind Map: creating, editing, and organizing mind maps on a canvas.",
                "本手册介绍「思维导图」的界面与基本操作：在画布上创建、编辑与组织思维导图。"
            ))
            .font(.appBody)
            .foregroundColor(theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface", "界面说明"))
            ManualBulletList(items: [
                .init(L(
                    "Top bar: the scope picker (In Project / In App), the map picker, 「New」, the delete button, and the zoom controls.",
                    "顶栏：作用域切换(In Project / In App)、导图选择器、「New」、删除按钮以及缩放控制。"
                )),
                .init(L(
                    "Canvas: shows the nodes of the current mind map; click a node to select it, and click it again to edit its text inline.",
                    "画布：显示当前思维导图的节点；点击节点即可选中，再次点击可在原位编辑文字。"
                )),
                .init(L(
                    "Node action bar: appears at the bottom when a node is selected, with 「Child」, 「Sibling」, 「Expand」 / 「Collapse」, and 「Delete」.",
                    "节点操作条：选中节点后出现在底部，提供「Child」「Sibling」「Expand」/「Collapse」与「Delete」。"
                )),
                .init(L(
                    "Rail 「Mind Maps」: the scope picker, the document list (each row shows its node count), and the New button.",
                    "侧栏「Mind Maps」：作用域切换、文档列表(每行显示节点数量)与新建按钮。"
                )),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations", "基本操作"))
            ManualStepList(items: [
                .init(L(
                    "Open the Mind Map tab in the sidebar.",
                    "在侧边栏中打开「思维导图」标签页。"
                )),
                .init(L(
                    "Click 「New」 to create an empty mind map, or ask the agent in chat, e.g. \"create a mind map about Swift concurrency\".",
                    "点击「New」新建空白导图，或在聊天中让 Agent 创建，例如“创建一个关于 Swift 并发的思维导图”。"
                )),
                .init(L(
                    "Click a node to select it; click it again and type to replace the text.",
                    "点击节点选中；再次点击即可输入文字。"
                )),
                .init(L(
                    "Use 「Child」 and 「Sibling」 in the node action bar to add a child node or a sibling node.",
                    "使用节点操作条中的「Child」与「Sibling」添加子节点或同级节点。"
                )),
                .init(L(
                    "Use 「Expand」 / 「Collapse」 to show or hide a node's children, and the zoom controls to zoom the canvas.",
                    "使用「Expand」/「Collapse」展开或折叠子节点，使用缩放控制调整画布大小。"
                )),
                .init(L(
                    "Use 「Delete」 to remove the selected node; use the trash button in the top bar to delete the whole map.",
                    "使用「Delete」删除所选节点；使用顶栏的删除按钮删除整张导图。"
                )),
            ])

            ManualSectionHeader(number: 4, title: L("What to Ask the AI", "让 AI 做什么"))
            ManualBulletList(items: [
                .init(L(
                    "Create a mind map from a topic in the conversation.",
                    "在对话中根据主题创建思维导图。"
                )),
                .init(L(
                    "Import an outline, such as a Markdown list, into a mind map.",
                    "将大纲(如 Markdown 列表)导入为思维导图。"
                )),
                .init(L(
                    "Edit nodes and export the current mind map.",
                    "编辑节点并导出当前思维导图。"
                )),
            ])

            ManualSectionHeader(number: 5, title: L("Notes", "注意事项"))
            ManualBulletList(items: [
                .init(L(
                    "Documents are grouped by scope: 「In Project」 maps are stored with the current project, and 「In App」 maps are available in every project.",
                    "文档按作用域分组：「项目内」导图随当前项目存储，「应用内」导图在所有项目中可用。"
                )),
                .init(L(
                    "The root node cannot be deleted; delete the whole map from the top bar or the rail list instead.",
                    "根节点无法删除；如需删除，请从顶栏或侧栏列表删除整张导图。"
                )),
                .init(L(
                    "With no mind map, the canvas shows an empty state with a create button.",
                    "没有导图时，画布显示空状态及创建按钮。"
                )),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout", "图 1 界面布局")) {
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
                    ManualFigureLegendItem(1, L("Top bar", "顶栏"))
                    ManualFigureLegendItem(2, L("Canvas", "画布"))
                    ManualFigureLegendItem(3, L("Node action bar", "节点操作条"))
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

    private func L(_ en: String, _ zh: String) -> String {
        MindMapLocalization.string(en, zh)
    }
}

#Preview {
    ScrollView {
        MindMapManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
