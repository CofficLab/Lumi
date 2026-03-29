import SwiftUI

// MARK: - 主题选择器
///
/// 用于选择和切换不同的神秘主题
///
struct ThemeSelectorView: View {
    // MARK: - 环境
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: - 主体
    var body: some View {
        VStack(spacing: AppUI.Spacing.sm) {
            ForEach(Themes.Variant.allCases, id: \.self) { variant in
                ThemeOptionCard(
                    variant: variant,
                    isSelected: themeManager.currentVariant == variant
                ) {
                    withAnimation(DesignAnimations.Preset.bounce) {
                        themeManager.currentVariant = variant
                        variant.save() // 保存到 UserDefaults
                    }
                }
            }
        }
    }
}

// MARK: - 主题选项卡片
struct ThemeOptionCard: View {
    let variant: Themes.Variant
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        GlassSelectionCard(
            isSelected: isSelected,
            checkmarkColor: variant.theme.iconColor,
            selectedBackgroundColor: variant.theme.iconColor.opacity(0.15),
            selectedBorderColor: variant.theme.iconColor,
            action: action
        ) {
            HStack(spacing: AppUI.Spacing.md) {
                // 图标
                Image(systemName: variant.theme.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? variant.theme.iconColor : AppUI.Color.semantic.textTertiary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                    // 名称
                    Text(variant.theme.displayName)
                        .font(AppUI.Typography.body)
                        .foregroundColor(isSelected ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)

                    // 描述
                    Text(variant.theme.description)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }
            }
        }
    }
}

// MARK: - Themes.Variant 扩展
extension Themes.Variant {
    /// 所有主题变体
    static var allCases: [Themes.Variant] {
        [
            .midnight,
            .aurora,
            .nebula,
            .void,
            .spring,
            .summer,
            .autumn,
            .winter,
            .orchard,
            .mountain,
            .river
        ]
    }

    // MARK: - 持久化

    /// UserDefaults 存储键
    private static let themeKey = "MystiqueTheme.SelectedVariant"

    /// 保存主题选择到 UserDefaults
    func save() {
        ThemeVariantStateStore.saveString(identifier, forKey: Self.themeKey)
    }

    /// 从 UserDefaults 加载保存的主题
    /// - Returns: 保存的主题，如果没有保存则返回默认的 .midnight
    static func loadSaved() -> Themes.Variant {
        let savedValue = ThemeVariantStateStore.loadString(forKey: themeKey)
        switch savedValue {
        case "midnight": return .midnight
        case "aurora": return .aurora
        case "nebula": return .nebula
        case "void": return .void
        case "spring": return .spring
        case "summer": return .summer
        case "autumn": return .autumn
        case "winter": return .winter
        case "orchard": return .orchard
        case "mountain": return .mountain
        case "river": return .river
        default: return .midnight
        }
    }
}

// MARK: - 预览
#Preview("主题选择器") {
    ThemeSelectorView()
        .mystiqueBackground()
        .environmentObject(ThemeManager())
}
