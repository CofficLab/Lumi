import SwiftUI
import LumiUI

// MARK: - Lumi 默认主题
///
/// 中性、低饱和的 IDE 配色，浅色/深色均参考系统风格，适合作为默认主题。
///
struct LumiTheme: LumiAppChromeTheme {
    let identifier = "lumi"
    let displayName = "Lumi"
    let compactName = "Lumi"
    let description = "均衡默认主题，随系统明暗自动适配"
    let iconName = "circle.hexagonpath.fill"
    let appearanceKind: ThemeAppearanceKind = .system

    func resolvedEditorThemeId(defaultEditorThemeId: String, colorScheme: ColorScheme) -> String {
        colorScheme == .dark ? "lumi-dark" : "lumi-light"
    }

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "007AFF", dark: "0A84FF")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color.adaptive(light: "007AFF", dark: "0A84FF"),
            secondary: SwiftUI.Color.adaptive(light: "5856D6", dark: "5E5CE6"),
            tertiary: SwiftUI.Color.adaptive(light: "34C759", dark: "30D158")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "F2F2F7", dark: "000000"),
            medium: SwiftUI.Color.adaptive(light: "FFFFFF", dark: "1C1C1E"),
            light: SwiftUI.Color.adaptive(light: "E5E5EA", dark: "2C2C2E")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "007AFF", dark: "0A84FF").opacity(0.12),
            medium: SwiftUI.Color.adaptive(light: "007AFF", dark: "0A84FF").opacity(0.22),
            intense: SwiftUI.Color.adaptive(light: "5856D6", dark: "5E5CE6").opacity(0.35)
        )
    }

    func workspaceBackgroundColor() -> SwiftUI.Color {
        atmosphereColors().medium
    }

    func sidebarBackgroundColor() -> SwiftUI.Color {
        atmosphereColors().deep
    }

    func workspaceTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    func workspaceSecondaryTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.85)
    }

    func workspaceTertiaryTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "98989E", dark: "98989E")
    }

    func sidebarSelectionTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "FFFFFF", dark: "FFFFFF")
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                Circle()
                    .fill(glowColors().subtle)
                    .frame(width: 520, height: 520)
                    .blur(radius: 100)
                    .offset(x: -proxy.size.width * 0.25, y: -proxy.size.height * 0.2)

                Circle()
                    .fill(glowColors().medium)
                    .frame(width: 420, height: 420)
                    .blur(radius: 90)
                    .position(x: proxy.size.width * 0.85, y: proxy.size.height * 0.75)
            }
        )
    }
}
