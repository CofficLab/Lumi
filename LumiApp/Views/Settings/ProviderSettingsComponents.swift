import LumiUI
import SwiftUI

struct ProviderSettingsProviderButton: View {
    @LumiTheme private var theme

    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
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
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? theme.primary.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProviderSettingsModelRow: View {
    @LumiTheme private var theme

    let model: String
    let isDefault: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(model)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isDefault {
                    Text("默认")
                        .font(.appCaption)
                        .foregroundColor(theme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(theme.primary.opacity(0.12))
                        )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
