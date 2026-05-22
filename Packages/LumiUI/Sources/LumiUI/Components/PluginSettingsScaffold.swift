import SwiftUI

/// Standard layout for plugin settings pages: fixed header card + scrollable content.
public struct PluginSettingsScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let content: Content

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = LocalizedStringKey(title)
        self.subtitle = subtitle.map { LocalizedStringKey($0) }
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            AppCard {
                if let subtitle {
                    AppSettingsSection(title, subtitle: subtitle) {}
                } else {
                    AppSettingsSection(title) {}
                }
            }
            .padding(24)
            .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

#Preview {
    PluginSettingsScaffold(title: "Example Plugin", subtitle: "Plugin-specific options") {
        AppCard {
            AppSettingsSection(title: "General") {
                AppSettingsToggleRow("Enable feature", isOn: .constant(true))
            }
        }
    }
    .frame(width: 480, height: 400)
}
