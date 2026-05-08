import SwiftUI

public struct AppDisclosureCard<Content: View>: View {
    @LumiTheme private var theme

    let title: LocalizedStringKey
    let icon: String?
    @ViewBuilder let content: Content

    @State private var isExpanded = false

    public init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = nil
        self.content = content()
    }

    public init(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
                .padding(.top, AppUI.Spacing.sm)
        } label: {
            HStack(spacing: AppUI.Spacing.sm) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 12)

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                }

                Text(title)
                    .font(AppUI.Typography.bodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .padding(AppUI.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                .fill(AppUI.Material.glass)
        )
    }
}
