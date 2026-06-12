import SwiftUI

/// Selectable provider row for LLM provider settings (title, subtitle, checkmark).
public struct AppSettingsProviderRow: View {
    @LumiTheme private var theme

    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    public init(
        title: String,
        subtitle: String = "",
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        GlassSelectionCard(
            isSelected: isSelected,
            selectedBackgroundColor: theme.primary.opacity(0.12),
            selectedBorderColor: nil,
            action: action
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
