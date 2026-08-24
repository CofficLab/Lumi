import LumiUI
import SwiftUI

// MARK: - Manual View

/// 终端使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct TerminalManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Terminal"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Terminal: creating terminal sessions, switching between tabs, and running commands."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Tab bar: shows one tab per terminal session; click a tab to switch, and use the close button on a tab to end it. The + button creates a new session.")),
                .init(L("Terminal area: the working area of the current session, where commands are entered and output is displayed.")),
                .init(L("When no terminals are open, an empty-state hint is shown.")),
                .init(L("The bottom panel also provides a Terminal tab whose sessions are separate from those in the view container.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Terminal tab.")),
                .init(L("Click + in the tab bar to create a new terminal session.")),
                .init(L("Click a tab to switch between sessions; use the close button on a tab to end it.")),
                .init(L("When a project is open, new sessions start in the project directory.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Disabling the plugin ends all terminal sessions; save your work first.")),
                .init(L("Sessions in the bottom panel and in the view container are independent of each other.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 标签栏:终端标签 + 新建按钮
                HStack(spacing: 6) {
                    tabMock(active: true)
                    tabMock(active: false)
                    plusPill()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 2)
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).offset(x: -4, y: -9) }

                // ② 终端区:提示符与输出示意
                VStack(alignment: .leading, spacing: 8) {
                    promptLineMock(width: 74)
                    outputLineMock(width: 110)
                    outputLineMock(width: 92)
                    promptLineMock(width: 30)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: 128)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Tab bar"))
                    ManualFigureLegendItem(2, L("Terminal area"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 终端标签示意:文字线 + 关闭按钮。
    private func tabMock(active: Bool) -> some View {
        HStack(spacing: 5) {
            lineMock(width: 34)
            Image(systemName: "xmark")
                .font(.system(size: 7))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(active ? Color.primary.opacity(0.08) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
        )
    }

    /// 新建会话按钮示意。
    private func plusPill() -> some View {
        Image(systemName: "plus")
            .font(.system(size: 9))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 命令行示意:提示符 + 文字线。
    private func promptLineMock(width: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 5) {
            Text("$")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(theme.textSecondary)
            lineMock(width: width)
        }
    }

    /// 命令输出示意:浅色文字线。
    private func outputLineMock(width: CGFloat) -> some View {
        lineMock(width: width)
            .opacity(0.6)
            .padding(.leading, 12)
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

#Preview {
    ScrollView {
        TerminalManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
