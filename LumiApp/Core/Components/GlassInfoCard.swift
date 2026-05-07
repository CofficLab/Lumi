import SwiftUI

// MARK: - 玻璃信息卡片
///
/// 带标题和图标的玻璃卡片，用于分组展示信息
///
struct GlassInfoCard<Content: View>: View {
    // MARK: - 配置
    var title: String
    var icon: String
    var iconColor: Color? = nil
    var subtitle: String? = nil
    var cornerRadius: CGFloat = DesignTokens.Radius.md
    var padding: EdgeInsets = DesignTokens.Spacing.cardPadding

    @ViewBuilder var content: Content

    // MARK: - 主体
    var body: some View {
        GlassCard(cornerRadius: cornerRadius, padding: padding) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // 标题栏
                header

                // 内容区域
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    content
                }
            }
        }
    }

    // MARK: - 标题栏
    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(iconColor ?? DesignTokens.Color.semantic.primary)

            VStack(alignment: .leading, spacing: 2) {
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

// MARK: - 预览
#Preview("信息卡片") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        GlassInfoCard(title: "App Information", icon: "info.circle.fill") {
            Text("App Name: Lumi")
            Text("Version: 1.0.0")
        }

        GlassInfoCard(
            title: "System Information",
            icon: "desktopcomputer",
            iconColor: .blue,
            subtitle: "Current system status"
        ) {
            Text("macOS 15.0")
            Text("Apple Silicon")
        }
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
