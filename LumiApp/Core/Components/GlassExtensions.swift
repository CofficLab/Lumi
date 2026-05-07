import SwiftUI

// MARK: - 辅助扩展
extension View {
    /// 发光效果
    func glowEffect(
        color: SwiftUI.Color,
        radius: CGFloat = 8,
        intensity: Double = 0.3
    ) -> some View {
        self.shadow(
            color: color.opacity(intensity),
            radius: radius,
            x: 0,
            y: 0
        )
    }

    /// 玻璃态覆盖
    func glassOverlay(opacity: Double = 0.1) -> some View {
        self.overlay(
            SwiftUI.Color.black.opacity(opacity)
                .background(DesignTokens.Material.glass)
        )
    }
}

// MARK: - 预览
#Preview("玻璃扩展效果") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        Text("发光效果")
            .font(DesignTokens.Typography.title3)
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

        HStack(spacing: DesignTokens.Spacing.lg) {
            Circle()
                .fill(DesignTokens.Color.semantic.primary)
                .frame(width: 50, height: 50)
                .glowEffect(color: .purple, radius: 15, intensity: 0.5)

            Circle()
                .fill(DesignTokens.Color.semantic.success)
                .frame(width: 50, height: 50)
                .glowEffect(color: .green, radius: 20, intensity: 0.6)
        }

        Divider()

        Text("玻璃覆盖效果")
            .font(DesignTokens.Typography.title3)
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

        VStack(spacing: DesignTokens.Spacing.md) {
            Text("原始内容")
                .padding()
                .background(DesignTokens.Color.semantic.primary)
                .cornerRadius(DesignTokens.Radius.md)

            Text("带玻璃覆盖")
                .padding()
                .background(DesignTokens.Color.semantic.success)
                .cornerRadius(DesignTokens.Radius.md)
                .glassOverlay(opacity: 0.2)
        }
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
