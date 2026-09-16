import LumiUI
import SwiftUI

// MARK: - Manual View

/// CAD 设计使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
public struct CADDesignerManualView: View {
    @LumiTheme private var theme

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("CAD Designer"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the CAD Designer: assembling profile frames, adjusting components, generating the bill of materials, and optimizing cuts."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Toolbar: provides New Project, Undo, Redo, Save, Load, and Export PNG.")),
                .init(L("Component library: the left pane groups profiles by series and lists connectors; use the search field to filter, and click + to add a component.")),
                .init(L("Viewport: the center area previews the design in 3D; when empty, it prompts you to add a profile.")),
                .init(L("Inspector: the right pane edits the selected component's length, position, and rotation, and provides Delete and Measure.")),
                .init(L("Bottom area: the bill of materials table, plus cut optimization with a stock length field and the Optimize button.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Create a new project with New Project, or load an existing one with Load.")),
                .init(L("Click + on a profile in the component library to add it to the viewport.")),
                .init(L("Select a component and adjust its length, position, and rotation in the inspector.")),
                .init(L("Add connectors from the component library to assemble the frame.")),
                .init(L("Review the bill of materials at the bottom of the workspace.")),
                .init(L("Enter the stock length and click Optimize to plan the cuts.")),
                .init(L("Click Export PNG to export an image of the design.")),
            ])

            ManualSectionHeader(number: 4, title: L("AI Operations"))
            ManualBulletList(items: [
                .init(L("Design complete profile frames from a description.")),
                .init(L("Generate and update the bill of materials for the current design.")),
            ])

            ManualSectionHeader(number: 5, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Save the project before closing to keep your changes.")),
                .init(L("Review the bill of materials after editing components; quantities follow the current design.")),
                .init(L("Cut optimization depends on the entered stock length; verify the result before cutting.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 0) {
                // ① 工具栏
                HStack(spacing: 6) {
                    toolbarPill("doc.badge.plus")
                    toolbarPill("arrow.uturn.backward")
                    toolbarPill("arrow.uturn.forward")
                    Spacer(minLength: 0)
                    toolbarPill("square.and.arrow.down")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .overlay(alignment: .top) { ManualFigureMarker(1).offset(y: -9) }

                Divider()

                HStack(spacing: 0) {
                    // ② 组件库
                    VStack(alignment: .leading, spacing: 6) {
                        searchPillMock()
                        groupLabel(L("Profiles"))
                        componentRowMock()
                        componentRowMock()
                        groupLabel(L("Connectors"))
                        componentRowMock()
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(width: 118, height: 128, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                    Divider()

                    // ③ 视口
                    ZStack {
                        profileFrameMock()
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 128)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }

                    Divider()

                    // ④ 属性面板
                    VStack(alignment: .leading, spacing: 6) {
                        fieldRowMock()
                        fieldRowMock()
                        fieldRowMock()
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(width: 96, height: 128, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(4).padding(-7) }
                }

                Divider()

                // ⑤ 物料清单
                VStack(alignment: .leading, spacing: 5) {
                    bomRowMock()
                    bomRowMock()
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .overlay(alignment: .topLeading) { ManualFigureMarker(5).padding(-7) }
            }

            HStack(spacing: 14) {
                ManualFigureLegendItem(1, L("Toolbar"))
                ManualFigureLegendItem(2, L("Component Library"))
                ManualFigureLegendItem(3, L("Viewport"))
                ManualFigureLegendItem(4, L("Inspector"))
                ManualFigureLegendItem(5, L("Bill of Materials"))
            }
            .padding(.top, 12)
        }
    }

    // MARK: - 示意简笔元素

    /// 侧边栏分组小标题。
    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(theme.textSecondary)
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

    /// 搜索框示意。
    private func searchPillMock() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary)
            lineMock(width: 30)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 组件行示意:截面小方块 + 文字线 + 加号。
    private func componentRowMock() -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(theme.appDivider)
                .frame(width: 12, height: 12)
            lineMock(width: 34)
            Spacer(minLength: 0)
            Image(systemName: "plus")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 视口中的型材框架示意:几根线段搭成的立体框架。
    private func profileFrameMock() -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let line = RoundedRectangle(cornerRadius: 1).fill(theme.primary.opacity(0.55))
            let back = RoundedRectangle(cornerRadius: 1).fill(theme.primary.opacity(0.2))

            // 后方面框
            back.frame(width: w * 0.42, height: h * 0.46)
                .offset(x: w * 0.26, y: h * 0.1)
            // 前方面框
            RoundedRectangle(cornerRadius: 1).strokeBorder(theme.primary.opacity(0.55), lineWidth: 2)
                .frame(width: w * 0.42, height: h * 0.46)
                .offset(x: w * 0.16, y: h * 0.28)
            // 连接棱
            back.frame(width: w * 0.34, height: 2).rotationEffect(.degrees(24))
                .offset(x: w * 0.2, y: h * 0.16)
            line.frame(width: w * 0.34, height: 2).rotationEffect(.degrees(24))
                .offset(x: w * 0.34, y: h * 0.6)
        }
    }

    /// 属性面板字段行示意。
    private func fieldRowMock() -> some View {
        VStack(alignment: .leading, spacing: 3) {
            lineMock(width: 28)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .frame(width: 72, height: 11)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
        }
    }

    /// 物料清单一行示意:编号 + 文字线 + 数量。
    private func bomRowMock() -> some View {
        HStack(spacing: 6) {
            lineMock(width: 14)
            lineMock(width: 80)
            Spacer(minLength: 0)
            lineMock(width: 12)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.04))
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
        CADDesignerLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        CADDesignerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
