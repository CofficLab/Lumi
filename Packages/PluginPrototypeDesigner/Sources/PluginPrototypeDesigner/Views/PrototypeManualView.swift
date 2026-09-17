import LumiUI
import SwiftUI

/// 原型设计器使用手册 —— 章节式文档：编号章节、编号步骤与线框示意图。
///
/// 通过 `pluginManualView` 暴露，在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct PrototypeManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Prototype Designer"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Prototype Designer: creating, editing, linking, and exporting product prototype screens."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Sidebar: prototype projects and their screens for the current project.")),
                .init(L("Toolbar: prototype style, device canvas, link count, Preview / HTML Source switch, Refresh, and Export.")),
                .init(L("Preview: shows the selected screen on the device canvas, scaled to fit.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Creating a Prototype"))
            ManualStepList(items: [
                .init(L("Open the Prototypes tab in the sidebar.")),
                .init(L("Describe your product and the screens you need, e.g. \"a three-screen checkout flow for a coffee app\".")),
                .init(L("The Agent picks a device canvas and a visual style, then writes each screen.")),
                .init(L("Review the rendered screens in the preview.")),
            ])

            ManualSectionHeader(number: 4, title: L("Editing a Screen"))
            ManualBulletList(items: [
                .init(L("State changes in the conversation, such as copy, layout, or color.")),
                .init(L("In Preview mode, right-click a region to draft an edit request for that block.")),
                .init(L("Small edits are applied as precise text replacements, so unrelated parts stay untouched.")),
            ])
            blockEditFigure

            ManualSectionHeader(number: 5, title: L("Connecting Screens"))
            ManualBulletList(items: [
                .init(L("Ask the Agent to link a control to another screen, e.g. \"make the primary button go to the detail screen\".")),
                .init(L("Links are declared in the HTML and shown as a count in the toolbar.")),
                .init(L("Links that point at a deleted screen are reported by the lint tool.")),
            ])

            ManualSectionHeader(number: 6, title: L("Exporting"))
            ManualStepList(items: [
                .init(L("Click Export and choose a folder.")),
                .init(L("Every screen is rendered as a PNG at the device's exact pixel size.")),
                .init(L("Files are named by screen order and slug, so the folder reads in flow order.")),
            ])
            exportFigure

            ManualSectionHeader(number: 7, title: L("Storage"))
            ManualBulletList(items: [
                .init(L("Prototypes are stored in the current project's .lumi/prototype directory.")),
                .init(L("Each screen is a standalone HTML document; imported images live in a shared assets folder.")),
                .init(L("No project open means the tools are unavailable.")),
            ])

            ManualSectionHeader(number: 8, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Screens are HTML documents. Scripts and remote resources are rejected; ask the Agent to import images into the project instead.")),
                .init(L("Changing the device canvas re-renders existing screens at the new size; check the preview afterwards.")),
                .init(L("Click Refresh in the toolbar if the list or preview looks out of date.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 侧边栏：项目与屏幕列表示意
                    VStack(alignment: .leading, spacing: 7) {
                        groupLabel(L("In Project"))
                        projectRowMock()
                        screenRowMock(indent: 14)
                        screenRowMock(indent: 14)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 132, height: 172, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    // 主区域：② 工具栏 + ③ 预览
                    VStack(spacing: 10) {
                        HStack(spacing: 5) {
                            Spacer(minLength: 0)
                            toolbarPill("rectangle.dashed")
                            toolbarPill("iphone")
                            segmentedMock()
                            toolbarPill("square.and.arrow.down")
                        }
                        .overlay(alignment: .top) { ManualFigureMarker(2).offset(y: -9) }

                        Spacer(minLength: 0)

                        deviceMock()

                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 172)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Sidebar"))
                    ManualFigureLegendItem(2, L("Toolbar"))
                    ManualFigureLegendItem(3, L("Preview"))
                }
            }
        }
    }

    // MARK: - 图 2 右键点击区块即可修改

    private var blockEditFigure: some View {
        ManualFigure(caption: L("Figure 2: Right-click a block to edit it")) {
            HStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text(L("Screen Title"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(theme.warning, lineWidth: 1.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "cursorarrow.click")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.warning)
                                .offset(x: 8, y: -10)
                        }

                    blockMock(height: 26)
                    blockMock(height: 26)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )

                VStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                    lineMock(width: 84)
                    lineMock(width: 64)
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 图 3 导出结果

    private var exportFigure: some View {
        ManualFigure(caption: L("Figure 3: Exported screens in flow order")) {
            VStack(alignment: .leading, spacing: 5) {
                treeRow(icon: "folder", text: "Export", mono: false, indent: 0)
                treeRow(icon: "doc", text: "01-home.png", mono: true, indent: 1)
                treeRow(icon: "doc", text: "02-detail.png", mono: true, indent: 1)
                treeRow(icon: "doc", text: "03-confirm.png", mono: true, indent: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 示意简笔元素

    /// 侧边栏分组小标题。
    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(theme.textSecondary)
    }

    /// 侧边栏项目行：画板图标 + 两根文字线。
    private func projectRowMock() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 48)
                lineMock(width: 30)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 侧边栏屏幕行：序号 + 单线。
    private func screenRowMock(indent: CGFloat) -> some View {
        HStack(spacing: 6) {
            // 纯装饰性序号，非文案：用 verbatim 避免被当作可翻译串提取。
            Text(verbatim: "1")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
            lineMock(width: 56)
        }
        .padding(.leading, indent)
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

    /// 「预览 / 源码」切换示意：两格相连的分段控件。
    private func segmentedMock() -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 16, height: 14)
            Rectangle().fill(Color.clear).frame(width: 16, height: 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 设备画板预览示意：竖版机身 + 内部区块。
    private func deviceMock() -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .frame(width: 78, height: 134)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.appDivider, lineWidth: 1.5)
            )
            .overlay {
                VStack(spacing: 5) {
                    lineMock(width: 26)
                    blockMock(height: 30)
                    blockMock(height: 18)
                    blockMock(height: 18)
                    Spacer(minLength: 0)
                }
                .padding(7)
            }
    }

    /// 内容区块示意。
    private func blockMock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.primary.opacity(0.06))
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.appDivider, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            )
    }

    /// 导出目录树行。
    private func treeRow(icon: String, text: String, mono: Bool, indent: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
            Text(text)
                .font(.system(size: mono ? 9 : 10, design: mono ? .monospaced : .default))
                .foregroundColor(theme.textPrimary)
        }
        .padding(.leading, indent * 18)
    }

    /// 示意图中的占位文字线。
    private func lineMock(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 3)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        PrototypeLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        PrototypeManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
