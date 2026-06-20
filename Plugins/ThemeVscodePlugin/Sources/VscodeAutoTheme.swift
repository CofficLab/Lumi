import SwiftUI
import LumiUI

// MARK: - VS Code 自适应主题
///
/// 跟随系统外观自动切换：暗色模式下等价于 VS Code Dark+，亮色模式下等价于 VS Code Light+。
/// 参考 LumiTheme 的 resolvedEditorThemeId 模式。
///
struct VscodeAutoTheme: LumiAppChromeTheme {
    // MARK: - 主题信息
    let identifier = "vscode-auto"
    let displayName = "VS Code"
    let compactName = "VSCode"
    let description = "随系统明暗自动切换 VS Code 亮色/深色配色"
    let iconName = "terminal"
    let appearanceKind: ThemeAppearanceKind = .system

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "007ACC", dark: "007ACC")
    }

    // MARK: - 编辑器主题解析

    func resolvedEditorThemeId(defaultEditorThemeId: String, colorScheme: ColorScheme) -> String {
        colorScheme == .dark ? "vscode-dark" : "vscode-light"
    }

    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        colorScheme == .dark ? .preset(.vscodeDark) : .preset(.vscodeLight)
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color.adaptive(light: "007ACC", dark: "007ACC"),
            secondary: SwiftUI.Color.adaptive(light: "A31515", dark: "C586C0"),
            tertiary: SwiftUI.Color.adaptive(light: "795E26", dark: "D7BA7D")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "F3F3F3", dark: "1E1E1E"),
            medium: SwiftUI.Color.adaptive(light: "FFFFFF", dark: "252526"),
            light: SwiftUI.Color.adaptive(light: "E8E8E8", dark: "2D2D2D")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "007ACC", dark: "007ACC").opacity(0.12),
            medium: SwiftUI.Color.adaptive(light: "007ACC", dark: "007ACC").opacity(0.22),
            intense: SwiftUI.Color.adaptive(light: "007ACC", dark: "C586C0").opacity(0.30)
        )
    }

    func workspaceTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "333333", dark: "CCCCCC")
    }

    func workspaceSecondaryTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "6A6A6A", dark: "969696")
    }

    func workspaceTertiaryTextColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "999999", dark: "6A6A6A")
    }

    func statusBarBackgroundColor() -> SwiftUI.Color {
        SwiftUI.Color(hex: "007ACC")
    }

    func statusBarForegroundColor() -> SwiftUI.Color {
        .white
    }

    func statusBarDividerColor() -> SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "000000", dark: "FFFFFF").opacity(0.12)
    }

    func statusBarItemBackgroundColor(isPresented: Bool) -> SwiftUI.Color {
        SwiftUI.Color.white.opacity(isPresented ? 0.24 : 0.16)
    }

    func statusBarItemForegroundColor() -> SwiftUI.Color {
        .white
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                atmosphereColors().deep
                    .ignoresSafeArea()

                // VS Code 蓝主光晕 (左上)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().primary.opacity(0.12),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 350
                        )
                    )
                    .frame(width: 700, height: 700)
                    .blur(radius: 130)
                    .position(x: 150, y: 150)

                // 次要色光晕 (右下)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().secondary.opacity(0.06),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .blur(radius: 100)
                    .position(x: proxy.size.width - 150, y: proxy.size.height - 150)

                // IDE 风格装饰
                ZStack {
                    Rectangle()
                        .fill(accentColors().primary.opacity(0.035))
                        .frame(width: 1, height: proxy.size.height)
                        .offset(x: -300)

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 350))
                        .foregroundStyle(accentColors().primary.opacity(0.025))
                        .rotationEffect(.degrees(-10))
                        .position(x: proxy.size.width * 0.7, y: proxy.size.height * 0.65)
                        .blur(radius: 3)

                    Image(systemName: "terminal")
                        .font(.system(size: 180))
                        .foregroundStyle(accentColors().secondary.opacity(0.03))
                        .rotationEffect(.degrees(8))
                        .position(x: proxy.size.width * 0.3, y: proxy.size.height * 0.25)
                        .blur(radius: 2)
                }
            }
        )
    }
}
