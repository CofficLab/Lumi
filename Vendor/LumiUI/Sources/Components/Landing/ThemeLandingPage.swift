import SwiftUI

/// 主题家族的共享落地页。
///
/// 各主题插件只传入自身的 `displayName` 与 `icon`,家族级介绍内容
/// (应用配色 / 编辑器配色 / 语法高亮调色板 / 即时切换)由本视图统一提供。
public struct ThemeLandingPage: View {
    @LumiTheme private var theme

    private let displayName: String
    private let icon: String

    public init(displayName: String, icon: String) {
        self.displayName = displayName
        self.icon = icon
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: icon,
                tagline: "\(displayName) 为应用与编辑器提供一套协调的配色,含语法高亮调色板,一键切换即刻生效。",
                chips: ["应用配色", "编辑器配色", "语法高亮"],
                metrics: [
                    .init(value: "全局", label: "应用与编辑器"),
                    .init(value: "调色板", label: "语法高亮"),
                    .init(value: "即时", label: "切换生效")
                ]
            )
            .landingAppear()

            LandingSpotlight(
                icon: "paintpalette",
                title: "一键切换整体外观",
                message: "\(displayName) 同时覆盖应用界面与编辑器,确保两边视觉协调统一。"
            ) {
                paletteSwatches
                    .padding(.top, 6)
            }
            .landingAppear(delay: 0.05)

            LandingSection(title: "核心能力", icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(icon: "rectangle.on.rectangle.angled", title: "应用界面配色",
                          description: "为整个应用界面提供协调的色彩方案。"),
                    .init(icon: "doc.richtext", title: "编辑器配色",
                          description: "为代码编辑器提供配套的外观。"),
                    .init(icon: "textformat", title: "语法高亮调色板",
                          description: "为各类语法元素提供清晰的色彩区分。"),
                    .init(icon: "bolt.fill", title: "即时生效",
                          description: "选择后立即应用,无需重启。")
                ])
            }
            .landingAppear(delay: 0.1)
        }
    }

    /// 用当前主题色拼出的一组色样,作为「主题影响配色」的示意。
    private var paletteSwatches: some View {
        HStack(spacing: 8) {
            ForEach([theme.primary, theme.info, theme.success, theme.warning, theme.error], id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(theme.appDivider, lineWidth: 1))
            }
        }
    }
}

#Preview {
    ScrollView {
        ThemeLandingPage(displayName: "Aurora Theme", icon: "aurora")
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
