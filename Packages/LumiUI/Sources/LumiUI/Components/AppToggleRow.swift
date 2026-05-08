import SwiftUI

public struct AppToggleRow: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let description: LocalizedStringKey?
    @Binding var isOn: Bool

    public init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        description: LocalizedStringKey? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self._isOn = isOn
    }

    public var body: some View {
        HStack(spacing: AppUI.Spacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(AppUI.Color.semantic.primary)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppUI.Typography.body)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                if let description {
                    Text(description)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, AppUI.Spacing.sm)
        .padding(.horizontal, AppUI.Spacing.md)
        .contentShape(Rectangle())
    }
}
