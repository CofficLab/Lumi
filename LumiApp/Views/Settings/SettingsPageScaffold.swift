import LumiUI
import SwiftUI

struct SettingsPageScaffold<Content: View>: View {
    @LumiTheme private var theme
    let title: String
    let subtitle: String
    let content: Content
    let maxContentWidth: CGFloat?
    let scrollsContent: Bool

    init(
        title: String,
        subtitle: String,
        maxContentWidth: CGFloat? = 640,
        scrollsContent: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.maxContentWidth = maxContentWidth
        self.scrollsContent = scrollsContent
        self.content = content()
    }

    var body: some View {
        Group {
            if scrollsContent {
                ScrollView {
                    scaffoldContent
                }
            } else {
                scaffoldContent
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var scaffoldContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
            }

            content
        }
        .padding(24)
        .frame(maxWidth: maxContentWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
