import SwiftUI
import LumiUI

// MARK: - 天空主题
///
/// 以昼夜天空为灵感，沿用 Lumi 的系统自适应模式。
///
struct SkyTheme: LumiAppChromeTheme {
    let identifier = "sky"
    let displayName = "天空"
    let compactName = "天空"
    let description = "晴空与夜幕之间，随系统明暗自动变换"
    let iconName = "cloud.sun.fill"
    let appearanceKind: ThemeAppearanceKind = .system

    func resolvedEditorThemeId(defaultEditorThemeId: String, colorScheme: ColorScheme) -> String {
        colorScheme == .dark ? "sky-dark" : "sky-light"
    }

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "0EA5E9", dark: "93C5FD")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color.adaptive(light: "0284C7", dark: "60A5FA"),
            secondary: SwiftUI.Color.adaptive(light: "F59E0B", dark: "FACC15"),
            tertiary: SwiftUI.Color.adaptive(light: "14B8A6", dark: "38BDF8")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "EAF7FF", dark: "07111F"),
            medium: SwiftUI.Color.adaptive(light: "FFFFFF", dark: "0D1B2E"),
            light: SwiftUI.Color.adaptive(light: "D7ECFF", dark: "162A44")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "38BDF8", dark: "60A5FA").opacity(0.20),
            medium: SwiftUI.Color.adaptive(light: "FBBF24", dark: "38BDF8").opacity(0.30),
            intense: SwiftUI.Color.adaptive(light: "0EA5E9", dark: "FACC15").opacity(0.38)
        )
    }

    func workspaceTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "102033", dark: "EAF6FF")
    }

    func workspaceSecondaryTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "4B647A", dark: "B6C8DA").opacity(0.88)
    }

    func workspaceTertiaryTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "7890A3", dark: "7F97AF")
    }

    func sidebarSelectionTextColor() -> SwiftUI.Color {
        SwiftUI.Color.white
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                Ellipse()
                    .fill(accentColors().secondary.opacity(0.16))
                    .frame(width: proxy.size.width * 1.2, height: 360)
                    .blur(radius: 95)
                    .position(x: proxy.size.width * 0.5, y: 20)

                Circle()
                    .fill(accentColors().primary.opacity(0.18))
                    .frame(width: 560, height: 560)
                    .blur(radius: 110)
                    .position(x: proxy.size.width * 0.88, y: proxy.size.height * 0.20)

                Circle()
                    .fill(accentColors().tertiary.opacity(0.14))
                    .frame(width: 520, height: 520)
                    .blur(radius: 120)
                    .position(x: proxy.size.width * 0.15, y: proxy.size.height * 0.85)

                Image(systemName: "cloud.fill")
                    .font(.system(size: 360))
                    .foregroundStyle(accentColors().primary.opacity(0.045))
                    .rotationEffect(.degrees(-8))
                    .position(x: proxy.size.width * 0.78, y: proxy.size.height * 0.78)
                    .blur(radius: 6)

                Image(systemName: "sparkle")
                    .font(.system(size: 140))
                    .foregroundStyle(accentColors().secondary.opacity(0.055))
                    .position(x: proxy.size.width * 0.18, y: proxy.size.height * 0.24)
                    .blur(radius: 3)
            }
        )
    }
}
