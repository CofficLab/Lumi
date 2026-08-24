import SwiftUI
import LumiUI

// MARK: - Lumi 默认主题（森林墨 Forest Ink）
///
/// 低饱和、内敛的编辑设计感配色：暖中性纸墨底 + 墨翠主色 + 天青/赭石点缀。
/// 浅色/深色均参考纸本书房的温润质感，随系统明暗自动适配。
///
struct LumiTheme: LumiAppChromeTheme {
    let identifier = "lumi"
    let displayName = "Lumi"
    let compactName = "Lumi"
    let description = "森林墨 · 低饱和暖底，随系统明暗自动适配"
    let iconName = "circle.hexagonpath.fill"
    let appearanceKind: ThemeAppearanceKind = .system

    func resolvedEditorThemeId(defaultEditorThemeId: String, colorScheme: ColorScheme) -> String {
        colorScheme == .dark ? "lumi-dark" : "lumi-light"
    }

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "059669", dark: "34D399")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            // primary = 墨翠（主强调 / 选中 / 主按钮）
            primary: SwiftUI.Color.adaptive(light: "059669", dark: "34D399"),
            // secondary = 赭石（暖色渐变伙伴，经 adapter 映射为 primarySecondary）
            secondary: SwiftUI.Color.adaptive(light: "D97706", dark: "F59E0B"),
            // tertiary = 天青（经 adapter 映射为 info，避免与 warning 橙撞色）
            tertiary: SwiftUI.Color.adaptive(light: "0EA5E9", dark: "38BDF8")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "FAFAF9", dark: "1C1C1A"), // 暖纸 / 暖墨
            medium: SwiftUI.Color.adaptive(light: "FFFFFF", dark: "262624"),
            light: SwiftUI.Color.adaptive(light: "E7E5E4", dark: "30302E")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "059669", dark: "34D399").opacity(0.10),
            medium: SwiftUI.Color.adaptive(light: "059669", dark: "34D399").opacity(0.16),
            intense: SwiftUI.Color.adaptive(light: "0EA5E9", dark: "38BDF8").opacity(0.22)
        )
    }

    func workspaceBackgroundColor() -> SwiftUI.Color {
        atmosphereColors().medium
    }

    func sidebarBackgroundColor() -> SwiftUI.Color {
        atmosphereColors().deep
    }

    func workspaceTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "1C1917", dark: "FAFAF9")
    }

    func workspaceSecondaryTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "57534E", dark: "D6D3D1").opacity(0.85)
    }

    func workspaceTertiaryTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "A8A29E", dark: "A8A29E")
    }

    func sidebarSelectionTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "FFFFFF", dark: "FFFFFF")
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                // 暖底渐变
                backgroundGradient()
                    .ignoresSafeArea()

                // 树影透光：左上柔和墨翠光晕
                Circle()
                    .fill(glowColors().medium)
                    .frame(width: 560, height: 560)
                    .blur(radius: 120)
                    .offset(x: -proxy.size.width * 0.22, y: -proxy.size.height * 0.35)

                // 右下天青微光，形成纵深层次
                Circle()
                    .fill(glowColors().subtle)
                    .frame(width: 420, height: 420)
                    .blur(radius: 110)
                    .position(x: proxy.size.width * 0.85, y: proxy.size.height * 0.8)
            }
        )
    }
}
