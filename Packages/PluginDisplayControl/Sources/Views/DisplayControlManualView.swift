import LumiUI
import SwiftUI

// MARK: - Manual View

/// 显示器控制使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct DisplayControlManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Display Control"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Display Control: adjusting brightness, volume, and contrast for each connected display."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Header card: shows the plugin name and a short description.")),
                .init(L("Display card: one card per display, with the display name, a built-in or external badge, and Brightness, Volume, and Contrast sliders ranging from 0 to 100%.")),
                .init(L("Restore Defaults card: the Restore button resets every display to its default settings.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Select the display card you want to adjust; each connected display has its own card.")),
                .init(L("Drag the Brightness, Volume, or Contrast slider to adjust the value from 0 to 100%.")),
                .init(L("Click Restore in the Restore Defaults card to reset all displays.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Support for external displays depends on the display model; unavailable controls are shown dimmed.")),
                .init(L("If no displays are detected, check the display connections and reopen the tab.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 10) {
                // ① 顶部头部卡示意
                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.primary.opacity(0.12))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "display")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.primary)
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        lineMock(width: 52)
                        lineMock(width: 76)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardFill)
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 显示器卡片:名称 + 徽标 + 三根滑杆
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.primary)
                        lineMock(width: 40)
                        Spacer(minLength: 0)
                        Text(L("External"))
                            .font(.system(size: 6, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(theme.primary.opacity(0.1)))
                    }
                    sliderRowMock(label: L("Brightness"), value: 0.68)
                    sliderRowMock(label: L("Volume"), value: 0.35)
                    sliderRowMock(label: L("Contrast"), value: 0.5)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardFill)
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                // ③ 恢复默认卡示意
                HStack(spacing: 6) {
                    lineMock(width: 56)
                    Spacer(minLength: 0)
                    toolbarPill("arrow.counterclockwise")
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardFill)
                .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                ManualFigureLegendItem(1, L("Header card"))
                ManualFigureLegendItem(2, L("Display card"))
                ManualFigureLegendItem(3, L("Restore Defaults card"))
            }
        }
    }

    // MARK: - 示意简笔元素

    private var cardFill: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(theme.appDivider)
    }

    /// 滑杆行示意:标签 + 轨道 + 百分比。
    private func sliderRowMock(label: String, value: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .frame(width: 38, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(theme.primary.opacity(0.55))
                        .frame(width: proxy.size.width * value)
                    Circle()
                        .fill(Color.white)
                        .shadow(radius: 0.5)
                        .frame(width: 7, height: 7)
                        .offset(x: proxy.size.width * value - 3.5)
                }
            }
            .frame(height: 7)
            Text("\(Int(value * 100))%")
                .font(.system(size: 7, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .frame(width: 22, alignment: .trailing)
        }
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
        DisplayControlManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
#endif
