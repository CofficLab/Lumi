import SwiftUI

// MARK: - 神秘感主题
///
/// 神秘感主题系统，支持动态主题加载和切换。
/// 现在可以轻松添加新主题，只需实现 ThemeProtocol 并注册到主题注册表。
///
enum Themes {
    // MARK: - 主题变体
    enum Variant: String, CaseIterable {
        case midnight   // 午夜幽蓝
        case aurora     // 极光紫
        case nebula     // 星云粉
        case void       // 虚空深黑
        case spring     // 春芽绿
        case summer     // 盛夏蓝
        case autumn     // 秋枫橙
        case winter     // 霜冬白
        case orchard    // 果园红
        case mountain   // 山岚灰
        case river      // 河流青

        /// 获取主题实例
        var theme: ThemeProtocol {
            switch self {
            case .midnight: return MidnightTheme()
            case .aurora: return AuroraTheme()
            case .nebula: return NebulaTheme()
            case .void: return VoidTheme()
            case .spring: return SpringTheme()
            case .summer: return SummerTheme()
            case .autumn: return AutumnTheme()
            case .winter: return WinterTheme()
            case .orchard: return OrchardTheme()
            case .mountain: return MountainTheme()
            case .river: return RiverTheme()
            }
        }

        /// 主题的字符串标识
        var identifier: String {
            rawValue
        }
    }

    // MARK: - 主题配置
    nonisolated(unsafe) static var currentVariant: Variant = .midnight {
        didSet {
            updateTheme()
        }
    }

    nonisolated(unsafe) static var isHighContrast: Bool = false
    nonisolated(unsafe) static var isReducedMotion: Bool = false

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

        init(variant: Variant = currentVariant) {
            let colors = variant.theme.accentColors()
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

        init(variant: Variant = currentVariant) {
            let colors = variant.theme.atmosphereColors()
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

        init(variant: Variant = currentVariant) {
            let colors = variant.theme.glowColors()
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
            currentVariant.theme.backgroundGradient()
        }

        /// 神秘光晕渐变
        static var mysticGlow: RadialGradient {
            currentVariant.theme.glowGradient()
        }

        /// 神秘边框渐变
        static var mysticBorder: LinearGradient {
            currentVariant.theme.borderGradient()
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

    // MARK: - 主题更新

    /// 更新主题时调用
    private static func updateTheme() {
        // 主题更新时会自动刷新 UI
    }
}

// MARK: - View 扩展 - 神秘效果
extension View {
    /// 神秘背景效果
    func mystiqueBackground(variant: Themes.Variant? = nil) -> some View {
        let themeVariant = variant ?? Themes.currentVariant
        return self
            .background(
                LinearGradient(
                    colors: [
                        themeVariant.theme.atmosphereColors().deep,
                        themeVariant.theme.atmosphereColors().medium,
                        themeVariant.theme.atmosphereColors().light
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    /// 神秘光晕效果
    func mystiqueGlow(intensity: Double = 0.15) -> some View {
        let colors = Themes.currentVariant.theme.glowColors()
        return self.glowEffect(
            color: colors.medium,
            radius: Themes.Effects.glowRadius,
            intensity: intensity
        )
    }

    /// 神秘边框
    func mystiqueBorder(cornerRadius: CGFloat = AppUI.Radius.md) -> some View {
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
            .font(AppUI.Typography.largeTitle)
            .foregroundColor(AppUI.Color.semantic.textPrimary)

        Text("午夜幽蓝氛围")
            .font(AppUI.Typography.body)
            .foregroundColor(AppUI.Color.semantic.textSecondary)
    }
    .mystiqueBackground(variant: .midnight)
}

#Preview("微光效果") {
    VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
        Text("微光效果卡片")
            .font(AppUI.Typography.title3)
            .foregroundColor(AppUI.Color.semantic.textPrimary)

        Text("神秘的微光会创造出梦幻的视觉效果")
            .font(AppUI.Typography.body)
            .foregroundColor(AppUI.Color.semantic.textSecondary)
    }
    .frame(width: 300)
    .padding(AppUI.Spacing.lg)
    .background(AppUI.Material.glass)
    .cornerRadius(AppUI.Radius.md)
    .mystiqueGlow(intensity: 0.2)
}

#Preview("脉冲光晕") {
    ZStack {
        AppUI.Color.basePalette.deepBackground.ignoresSafeArea()

        VStack(spacing: AppUI.Spacing.xl) {
            Circle()
                .fill(Themes.Colors.glow.intense)
                .frame(width: 100, height: 100)
                .opacity(0.8)

            Circle()
                .fill(AppUI.Color.semantic.success)
                .frame(width: 80, height: 80)
                .opacity(0.8)

            Circle()
                .fill(AppUI.Color.semantic.error)
                .frame(width: 60, height: 60)
                .opacity(0.8)
        }
    }
}

#Preview("主题变体") {
    ScrollView(.vertical) {
        VStack(spacing: AppUI.Spacing.lg) {
            ForEach(Themes.Variant.allCases, id: \.self) { variant in
                GlassCard {
                    HStack {
                        // 使用每个主题的特定颜色
                        ZStack {
                            Circle()
                                .fill(variant.theme.iconColor)
                                .opacity(0.2)
                                .frame(width: 48, height: 48)

                            Image(systemName: variant.theme.iconName)
                                .font(.system(size: 20))
                                .foregroundColor(variant.theme.iconColor)
                        }

                        VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                            Text(variant.theme.displayName)
                                .font(AppUI.Typography.bodyEmphasized)
                                .foregroundColor(AppUI.Color.semantic.textPrimary)

                            Text(variant.theme.description)
                                .font(AppUI.Typography.caption1)
                                .foregroundColor(AppUI.Color.semantic.textTertiary)
                        }

                        Spacer()

                        // 色彩示例点
                        Circle()
                            .fill(variant.theme.iconColor)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: AppUI.Radius.md)
                        .stroke(variant.theme.iconColor, lineWidth: 1)
                        .opacity(0.5)
                )
                .mystiqueGlow(intensity: 0.2)
                .frame(width: 280)
            }
        }
        .padding(AppUI.Spacing.lg)
    }
    .mystiqueBackground()
    .frame(height: 600)
    .frame(width: 500)
}

private func variantName(for variant: Themes.Variant) -> String {
    switch variant {
    case .midnight: return "午夜幽蓝"
    case .aurora: return "极光紫"
    case .nebula: return "星云粉"
    case .void: return "虚空深黑"
    case .spring: return "春芽绿"
    case .summer: return "盛夏蓝"
    case .autumn: return "秋枫橙"
    case .winter: return "霜冬白"
    case .orchard: return "果园红"
    case .mountain: return "山岚灰"
    case .river: return "河流青"
    }
}
