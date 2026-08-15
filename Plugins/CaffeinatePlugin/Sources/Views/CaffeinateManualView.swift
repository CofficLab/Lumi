import LumiUI
import SwiftUI

// MARK: - Manual View

/// 防休眠插件使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct CaffeinateManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Caffeinate"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of Caffeinate, which keeps your Mac awake during long-running tasks such as downloads, rendering, and presentations."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Menu Bar"))
            ManualBulletList(items: [
                .init(L("Menu bar icon: click it to open the popup; the icon shows whether Caffeinate is running.")),
                .init(L("Duration options: Indefinite, 10 Min, 1 Hour, 2 Hours, and 5 Hours. The Mac stays awake until the timer expires.")),
                .init(L("Quick actions: Prevent sleep & Keep screen on, Prevent sleep & Allow screen off, and Prevent sleep & Turn off screen.")),
            ])
            menuFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Click the Caffeinate icon in the menu bar to open the popup.")),
                .init(L("Choose a duration to start preventing sleep, or tap one of the three quick actions to set how the screen behaves.")),
                .init(L("Tap the active option again to stop; a timed session also ends automatically when the timer expires.")),
                .init(L("You can also ask the AI in the chat to turn Caffeinate on or off.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Keeping the screen on increases power consumption; prefer Allow screen off or Turn off screen when the display is not needed.")),
                .init(L("Indefinite mode keeps the Mac awake until you stop it manually.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 菜单栏弹窗

    private var menuFigure: some View {
        ManualFigure(caption: L("Figure 1: Menu bar popup")) {
            VStack(spacing: 12) {
                // 菜单栏条:① 防休眠图标
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .overlay(alignment: .top) { ManualFigureMarker(1).offset(y: -11) }
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) { Divider() }

                // 弹窗示意:② 时长选项 + ③ 快捷操作
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        durationPill(L("Indefinite"))
                        durationPill(L("10 Min"))
                        durationPill(L("1 Hour"))
                        durationPill(L("2 Hours"))
                        durationPill(L("5 Hours"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                    Divider()

                    VStack(spacing: 0) {
                        actionRowMock(icon: "sun.max.fill")
                        Divider().padding(.leading, 26)
                        actionRowMock(icon: "moon.fill")
                        Divider().padding(.leading, 26)
                        actionRowMock(icon: "power")
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottomLeading) { ManualFigureMarker(3).padding(-7) }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Menu bar icon"))
                    ManualFigureLegendItem(2, L("Duration options"))
                    ManualFigureLegendItem(3, L("Quick actions"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 时长选项按钮示意。
    private func durationPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 7))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
    }

    /// 快捷操作行示意:图标 + 两根文字线。
    private func actionRowMock(icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 96)
                lineMock(width: 56)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
        CaffeinateManualView()
            .padding(22)
    }
    .frame(width: 560, height: 800)
}
