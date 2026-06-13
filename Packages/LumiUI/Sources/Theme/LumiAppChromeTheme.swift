import SwiftUI

// MARK: - App Chrome Theme

/// IDE / 应用外壳主题协议（工作区、侧栏、全局背景等）。
/// 插件主题实现此协议；组件库语义色见 ``LumiUITheme``。
public protocol LumiAppChromeTheme {
    var identifier: String { get }
    var displayName: String { get }
    var compactName: String { get }
    var description: String { get }
    var iconName: String { get }
    var iconColor: Color { get }
    /// 主题外观类型（暗色 / 亮色 / 跟随系统）。
    var appearanceKind: ThemeAppearanceKind { get }

    func resolvedEditorThemeId(defaultEditorThemeId: String, colorScheme: ColorScheme) -> String

    /// 与此外壳主题配套的编辑器语法调色板。
    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color)
    func atmosphereColors() -> (deep: Color, medium: Color, light: Color)
    func glowColors() -> (subtle: Color, medium: Color, intense: Color)

    func backgroundGradient() -> LinearGradient
    func glowGradient() -> RadialGradient
    func borderGradient() -> LinearGradient

    func workspaceBackgroundColor() -> Color
    func sidebarBackgroundColor() -> Color
    func sidebarSelectionColor() -> Color
    func sidebarSelectionTextColor() -> Color
    func workspaceTextColor() -> Color
    func workspaceSecondaryTextColor() -> Color
    func workspaceTertiaryTextColor() -> Color
    func statusBarBackgroundColor() -> Color
    func statusBarForegroundColor() -> Color
    func statusBarDividerColor() -> Color
    func statusBarItemBackgroundColor(isPresented: Bool) -> Color
    func statusBarItemForegroundColor() -> Color

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView
}

// MARK: - Default Implementations

public extension LumiAppChromeTheme {
    var isDarkTheme: Bool { appearanceKind == .dark }

    var followsSystemAppearance: Bool { appearanceKind == .system }

    /// 对跟随系统的主题，按 macOS 有效外观解析；否则由 `appearanceKind` 决定。
    @MainActor
    var effectiveIsDarkTheme: Bool {
        switch appearanceKind {
        case .dark: return true
        case .light: return false
        case .system:
            return SystemAppearanceResolver.effectiveColorScheme == .dark
        }
    }

    func resolvedEditorThemeId(defaultEditorThemeId: String, colorScheme: ColorScheme) -> String {
        defaultEditorThemeId
    }

    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        EditorSyntaxPalette.derived(from: self, colorScheme: colorScheme)
    }

    func workspaceBackgroundColor() -> Color {
        atmosphereColors().medium
    }

    func sidebarBackgroundColor() -> Color {
        atmosphereColors().deep
    }

    func sidebarSelectionColor() -> Color {
        accentColors().primary.opacity(0.22)
    }

    func sidebarSelectionTextColor() -> Color {
        workspaceTextColor()
    }

    func workspaceTextColor() -> Color {
        Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    func workspaceSecondaryTextColor() -> Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.72)
    }

    func workspaceTertiaryTextColor() -> Color {
        Color.adaptive(light: "98989E", dark: "EBEBF5").opacity(0.48)
    }

    func statusBarBackgroundColor() -> Color {
        atmosphereColors().medium
    }

    func statusBarForegroundColor() -> Color {
        workspaceTextColor()
    }

    func statusBarDividerColor() -> Color {
        workspaceTertiaryTextColor().opacity(0.18)
    }

    func statusBarItemBackgroundColor(isPresented: Bool) -> Color {
        if isPresented {
            return accentColors().primary.opacity(0.14)
        }
        return workspaceTextColor().opacity(0.08)
    }

    func statusBarItemForegroundColor() -> Color {
        workspaceTextColor()
    }

    func backgroundGradient() -> LinearGradient {
        let colors = atmosphereColors()
        return LinearGradient(
            colors: [colors.deep, colors.medium, colors.light, colors.medium, colors.deep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func glowGradient() -> RadialGradient {
        let colors = glowColors()
        return RadialGradient(
            colors: [colors.intense, colors.medium, colors.subtle, Color.clear],
            center: .center,
            startRadius: 0,
            endRadius: 250
        )
    }

    func borderGradient() -> LinearGradient {
        LinearGradient(
            colors: [Color.clear, Color.white.opacity(0.15), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                Circle()
                    .fill(glowGradient())
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .offset(x: -200, y: -200)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glowColors().intense, glowColors().medium, Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .frame(width: 500, height: 500)
                    .blur(radius: 120)
                    .position(x: proxy.size.width, y: proxy.size.height)
            }
        )
    }
}
