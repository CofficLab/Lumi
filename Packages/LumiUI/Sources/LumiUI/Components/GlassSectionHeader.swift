import SwiftUI

public struct GlassSectionHeader: View {
    var icon: String
    var title: String
    var subtitle: String? = nil
    var iconColor: Color? = nil
    var spacing: CGFloat

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        iconColor: Color? = nil,
        spacing: CGFloat = 16
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.spacing = spacing
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor ?? DesignTokens.Color.semantic.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    if let subtitle {
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
