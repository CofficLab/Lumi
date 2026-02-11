import SwiftUI

// MARK: - 精致玻璃卡片
///
/// 玻璃态卡片组件，提供优雅的毛玻璃效果。
/// 特点：
/// - 背景模糊（ultraThinMaterial）
/// - 深色叠加层（增强对比）
/// - 微妙渐变边框
/// - 柔和阴影
///
struct MystiqueGlassCard<Content: View>: View {
    // MARK: - 配置
    var cornerRadius: CGFloat = DesignTokens.Radius.md
    var padding: EdgeInsets = DesignTokens.Spacing.cardPadding
    var shadowIntensity: Double = 1.0
    var glowColor: SwiftUI.Color? = nil
    var borderIntensity: Double = 0.08

    @ViewBuilder var content: Content

    // MARK: - 主体
    var body: some View {
        content
            .padding(padding)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
            .glowEffect(
                color: glowColor ?? DesignTokens.Color.basePalette.glowAccent,
                radius: glowRadius,
                intensity: glowIntensity
            )
    }

    // MARK: - 私有属性
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignTokens.Material.glass)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignTokens.Material.mysticGlass(opacity: 0.4))
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                LinearGradient(
                    colors: [
                        SwiftUI.Color.clear,
                        SwiftUI.Color.white.opacity(borderIntensity),
                        SwiftUI.Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var shadowColor: SwiftUI.Color {
        DesignTokens.Shadow.subtle.opacity(shadowIntensity)
    }

    private var shadowRadius: CGFloat {
        DesignTokens.Shadow.subtleRadius
    }

    private var shadowOffset: CGFloat {
        DesignTokens.Shadow.subtleOffset
    }

    private var glowRadius: CGFloat {
        glowColor != nil ? 12 : 0
    }

    private var glowIntensity: Double {
        glowColor != nil ? 0.3 : 0
    }
}

// MARK: - 预览
#Preview("玻璃卡片") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        MystiqueGlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("玻璃卡片")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text("精致的毛玻璃效果，带有微妙边框和柔和阴影")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }

        MystiqueGlassCard(glowColor: .purple) {
            Text("带光晕的卡片")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
        }
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
