import SwiftUI

public struct GlassInfoCard<Content: View>: View {
    @LumiTheme private var theme

    var title: String
    var icon: String
    var iconColor: Color?
    var subtitle: String?
    var cornerRadius: CGFloat
    var padding: EdgeInsets

    @ViewBuilder var content: Content

    public init(
        title: String,
        icon: String,
        iconColor: Color? = nil,
        subtitle: String? = nil,
        cornerRadius: CGFloat = 16,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.subtitle = subtitle
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        GlassCard(cornerRadius: cornerRadius, padding: padding) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                header
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    content
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(iconColor ?? theme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.bodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(theme.textTertiary)
                }
            }

            Spacer()
        }
    }
}
