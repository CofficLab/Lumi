import SwiftUI

/// Standard layout for plugin settings pages.
///
/// Plugin views can keep their domain-specific content while inheriting the
/// same canvas, spacing, scrolling and card language as the built-in settings.
public struct PluginSettingsScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let showHeader: Bool
    let scrollsContent: Bool
    let content: Content

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        showHeader: Bool = true,
        scrollsContent: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showHeader = showHeader
        self.scrollsContent = scrollsContent
        self.content = content()
    }

    public init(
        title: String,
        subtitle: String? = nil,
        showHeader: Bool = true,
        scrollsContent: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = LocalizedStringKey(title)
        self.subtitle = subtitle.map { LocalizedStringKey($0) }
        self.showHeader = showHeader
        self.scrollsContent = scrollsContent
        self.content = content()
    }

    public var body: some View {
        AppSettingsContentScaffold(scrollsContent: scrollsContent, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                if showHeader {
                    AppSettingsSection(title, subtitle: subtitle) {}
                }

                content
                Spacer(minLength: 0)
            }
        }
        .environment(\.appSettingsCardStyleOverride, .subtle)
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
