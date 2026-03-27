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
        VStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(Themes.Variant.allCases, id: \.self) { variant in
                ThemeOptionCard(
                    variant: variant,
                    isSelected: themeManager.currentVariant == variant,
                    action: {
                        withAnimation(DesignAnimations.Preset.bounce) {
                            themeManager.currentVariant = variant
                        }
                    }
                )
            }
        }
    }
}

// MARK: - 主题选项卡片
struct ThemeOptionCard: View {
    let variant: Themes.Variant
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 图标
                themeIcon
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? variant.theme.iconColor : DesignTokens.Color.semantic.textTertiary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    // 名称
                    Text(variant.theme.displayName)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)

                    // 描述
                    Text(variant.theme.description)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }

                Spacer()

                // 选中指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(variant.theme.iconColor)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(cardBackground)
            .overlay(cardBorder)
            .cornerRadius(DesignTokens.Radius.md)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DesignAnimations.Preset.responsive, value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var themeIcon: some View {
        Image(systemName: variant.theme.iconName)
    }

    @ViewBuilder private var cardBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(variant.theme.iconColor.opacity(0.15))
        } else if isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(DesignTokens.Material.glass.opacity(0.1))
        }
    }

    @ViewBuilder private var cardBorder: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(variant.theme.iconColor, lineWidth: 2)
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(SwiftUI.Color.white.opacity(0.08), lineWidth: 1)
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
