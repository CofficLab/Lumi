import SwiftUI

// MARK: - 玻璃分组标题
///
/// 设置页面的分组标题，带有图标、标题和描述
///
struct GlassSectionHeader: View {
    // MARK: - 配置
    var icon: String
    var title: String
    var subtitle: String? = nil
    var iconColor: Color? = nil
    var spacing: CGFloat = DesignTokens.Spacing.md

    // MARK: - 主体
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor ?? DesignTokens.Color.semantic.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - 预览
#Preview("分组标题") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
        GlassSectionHeader(
            icon: "power",
            title: "启动选项",
            subtitle: "管理应用启动行为"
        )

        GlassSectionHeader(
            icon: "graduationcap",
            title: "新手引导",
            subtitle: "随时重新查看产品使用指引"
        )

        GlassSectionHeader(
            icon: "lifepreserver",
            title: "反馈与支持",
            iconColor: .blue
        )
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
