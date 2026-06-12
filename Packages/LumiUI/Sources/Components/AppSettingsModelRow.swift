import SwiftUI

/// Selectable model row for LLM provider settings.
public struct AppSettingsModelRow: View {
    @LumiTheme private var theme

    let model: String
    let isDefault: Bool
    let defaultLabel: String
    let onTap: () -> Void

    public init(
        model: String,
        isDefault: Bool,
        defaultLabel: String = "默认",
        onTap: @escaping () -> Void
    ) {
        self.model = model
        self.isDefault = isDefault
        self.defaultLabel = defaultLabel
        self.onTap = onTap
    }

    public var body: some View {
        AppListRow(isSelected: isDefault, action: onTap) {
            HStack(spacing: 12) {
                Text(model)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isDefault {
                    AppTag(defaultLabel, style: .accent)
                }
            }
        }
    }
}
