import SwiftUI
import LumiUI

// MARK: - 神秘感主题
///
/// 神秘感主题系统，支持动态主题加载和切换。
/// 现在可以轻松添加新主题，只需实现 SuperTheme 并注册到主题注册表。
///
enum Themes {
    /// 统一主题对象（由 `AppThemeVM` 在启动时从插件主题写入）
    nonisolated(unsafe) static var currentTheme: any SuperTheme = UnconfiguredAppTheme()

    // MARK: - 颜色配置（动态加载）

    /// 主题颜色（基于当前选中主题）
    enum Colors {
        /// 主色调
        static let accent = AccentColors()
        /// 氛围色
        static let atmosphere = AtmosphereColors()
        /// 光晕色
        static let glow = GlowColors()
    }

    // MARK: - 强调色
    struct AccentColors {
        let primary: SwiftUI.Color
        let secondary: SwiftUI.Color
        let tertiary: SwiftUI.Color

        init(theme: (any SuperTheme)? = nil) {
            let colors = (theme ?? currentTheme).accentColors()
            self.primary = colors.primary
            self.secondary = colors.secondary
            self.tertiary = colors.tertiary
        }
    }

    // MARK: - 氛围色
    struct AtmosphereColors {
        let deep: SwiftUI.Color
        let medium: SwiftUI.Color
        let light: SwiftUI.Color

        init(theme: (any SuperTheme)? = nil) {
            let colors = (theme ?? currentTheme).atmosphereColors()
            self.deep = colors.deep
            self.medium = colors.medium
            self.light = colors.light
        }
    }

    // MARK: - 光晕色
    struct GlowColors {
        let subtle: SwiftUI.Color
        let medium: SwiftUI.Color
        let intense: SwiftUI.Color

        init(theme: (any SuperTheme)? = nil) {
            let colors = (theme ?? currentTheme).glowColors()
            self.subtle = colors.subtle
            self.medium = colors.medium
            self.intense = colors.intense
        }
    }

    // MARK: - 渐变配置（动态加载）

    /// 主题渐变（基于当前选中主题）
    enum Gradients {
        /// 极光背景渐变
        static var auroraBackground: LinearGradient {
            currentTheme.backgroundGradient()
        }

        /// 神秘光晕渐变
        static var mysticGlow: RadialGradient {
            currentTheme.glowGradient()
        }

        /// 神秘边框渐变
        static var mysticBorder: LinearGradient {
            currentTheme.borderGradient()
        }
    }

    // MARK: - 效果配置

    /// 主题效果
    enum Effects {
        /// 光晕半径
        static let glowRadius: CGFloat = 12
        /// 动画持续时间
        static let animationDuration: Double = 0.3
    }

}

// MARK: - 启动占位主题

/// `AppThemeVM` 应用插件主题前的占位，内核不引用任何插件主题类型。
private struct UnconfiguredAppTheme: SuperTheme {
    let identifier = "__unconfigured__"
    let displayName = ""
    let compactName = ""
    let description = ""
    let iconName = "circle.dashed"
    let iconColor = SwiftUI.Color.clear

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (.clear, .clear, .clear)
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (.clear, .clear, .clear)
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (.clear, .clear, .clear)
    }
}

// MARK: - View 扩展 - 神秘效果
extension View {
    /// 神秘背景效果
    func mystiqueBackground(theme: (any SuperTheme)? = nil) -> some View {
        let activeTheme = theme ?? Themes.currentTheme
        return self
            .background(
                LinearGradient(
                    colors: [
                        activeTheme.atmosphereColors().deep,
                        activeTheme.atmosphereColors().medium,
                        activeTheme.atmosphereColors().light
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    /// 神秘光晕效果
    func mystiqueGlow(intensity: Double = 0.15) -> some View {
        let colors = Themes.currentTheme.glowColors()
        return self.glowEffect(
            color: colors.medium,
            radius: Themes.Effects.glowRadius,
            intensity: intensity
        )
    }

    /// 神秘边框
    func mystiqueBorder(cornerRadius: CGFloat = 16) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Themes.Gradients.mysticBorder, lineWidth: 1.5)
        )
    }
}

// MARK: - 预览
#Preview("神秘主题背景") {
    VStack {
        Text("神秘主题")
            .font(.system(size: 34, weight: .bold))
            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

        Text("由 AppThemeVM 驱动当前主题")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
    }
    .mystiqueBackground()
}

#Preview("微光效果") {
    VStack(alignment: .leading, spacing: 16) {
        Text("微光效果卡片")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

        Text("神秘的微光会创造出梦幻的视觉效果")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
    }
    .frame(width: 300)
    .padding(24)
    .background(Material.regularMaterial)
    .cornerRadius(16)
    .mystiqueGlow(intensity: 0.2)
}

