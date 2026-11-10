import SwiftUI

/// 只读信息行：图标 + 标题 + 描述（Cisum 贡献）。
public struct AppInfoRow: View {
    @LumiTheme private var theme

    let icon: String
    let title: Text
    let description: Text
    let tint: Color

    public init(icon: String, title: String, description: String, tint: Color? = nil) {
        self.icon = icon
        self.title = Text(title)
        self.description = Text(description)
        self.tint = tint ?? .accentColor
    }

    public init(icon: String, title: LocalizedStringKey, description: LocalizedStringKey, tint: Color? = nil) {
        self.icon = icon
        self.title = Text(title)
        self.description = Text(description)
        self.tint = tint ?? .accentColor
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(AppUI.Typography.bodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                description
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        AppInfoRow(
            icon: "externaldrive.fill",
            title: "Storage Location Reset",
            description: "The media storage selection will be cleared",
            tint: .orange
        )
        AppInfoRow(
            icon: "slider.horizontal.3",
            title: "Preferences Kept",
            description: "Playback, theme, and library records are not deleted",
            tint: .orange
        )
    }
    .padding()
    .frame(width: 320)
}
