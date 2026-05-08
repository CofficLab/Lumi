import SwiftUI

public struct AppEmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey?
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    public init(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = nil
        self.action = nil
    }

    public init(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: AppUI.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppUI.Color.semantic.textSecondary.opacity(0.6))

            Text(title)
                .font(AppUI.Typography.bodyEmphasized)
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            if let description {
                Text(description)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                AppButton(actionTitle, style: .secondary, size: .small, action: action)
                    .padding(.top, AppUI.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppUI.Spacing.xl)
    }
}
