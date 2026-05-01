import SwiftUI

// MARK: - 设计系统预览
#Preview("颜色系统") {
    VStack(spacing: DesignTokens.Spacing.md) {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ColorSwatch(name: "深背景", color: DesignTokens.Color.basePalette.deepBackground)
            ColorSwatch(name: "表面", color: DesignTokens.Color.basePalette.surfaceBackground)
            ColorSwatch(name: "靛紫", color: DesignTokens.Color.basePalette.mysticIndigo)
            ColorSwatch(name: "幽光", color: DesignTokens.Color.basePalette.glowAccent)
        }

        HStack(spacing: DesignTokens.Spacing.sm) {
            ColorSwatch(name: "主紫", color: DesignTokens.Color.semantic.primary)
            ColorSwatch(name: "成功", color: DesignTokens.Color.semantic.success)
            ColorSwatch(name: "警告", color: DesignTokens.Color.semantic.warning)
            ColorSwatch(name: "错误", color: DesignTokens.Color.semantic.error)
        }

        GradientSwatch(name: "主渐变", gradient: DesignTokens.Color.gradients.primaryGradient)
        GradientSwatch(name: "极光", gradient: DesignTokens.Color.gradients.auroraGradient)
    }
    .padding(DesignTokens.Spacing.lg)
    .background(DesignTokens.Color.basePalette.deepBackground)
}

struct ColorSwatch: View {
    let name: String
    let color: SwiftUI.Color

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 50, height: 50)
            Text(name)
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
    }
}

struct GradientSwatch: View {
    let name: String
    let gradient: LinearGradient

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(gradient)
                .frame(height: 50)
            Text(name)
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
    }
}
