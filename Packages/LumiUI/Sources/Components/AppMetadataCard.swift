import SwiftUI

/// A quiet card for presenting a group of read-only metadata rows.
///
/// The card intentionally leaves row content to the caller so it can be used
/// for URLs, badges, copy actions, and other values without coupling LumiUI
/// to a particular feature.
public struct AppMetadataCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    public init(
        cornerRadius: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        AppCard(
            style: .subtle,
            cornerRadius: cornerRadius,
            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
            showShadow: false
        ) {
            VStack(spacing: 0) {
                content
            }
        }
    }
}

/// A read-only metadata row with a leading symbol, label, and custom value.
///
/// The value view remains fully customizable, while the icon and label follow
/// the same spacing and typography used by LumiUI settings surfaces.
public struct AppMetadataRow<Value: View>: View {
    @LumiTheme private var theme

    let title: String
    let systemImage: String
    let labelWidth: CGFloat
    let value: Value

    public init(
        title: String,
        systemImage: String,
        labelWidth: CGFloat = 112,
        @ViewBuilder value: () -> Value
    ) {
        self.title = title
        self.systemImage = systemImage
        self.labelWidth = labelWidth
        self.value = value()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.appBody)
                .foregroundStyle(theme.textSecondary)
                .frame(width: labelWidth, alignment: .leading)

            value
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    AppMetadataCard {
        AppMetadataRow(title: "Method", systemImage: "arrow.left.arrow.right") {
            AppTag("POST", systemImage: "arrow.up.right", style: .accent)
        }
        AppSettingsDivider()
        AppMetadataRow(title: "URL", systemImage: "link") {
            Text("https://example.com/v1/chat/completions")
                .font(.appMonoCaption)
                .textSelection(.enabled)
        }
        AppSettingsDivider()
        AppMetadataRow(title: "Duration", systemImage: "clock") {
            Text("2.762 s")
                .font(.appBody)
        }
    }
    .padding()
    .frame(width: 620)
}
