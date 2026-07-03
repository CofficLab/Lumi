import SwiftUI

/// A settings tab contributed by a plugin to appear in the app Settings sidebar.
///
/// Plugins return instances of this model from `addSettingsTabs(context:)` to
/// register their own top-level settings entries in the plugin section below
/// core tabs like General, Appearance, and Plugins.
@MainActor
public struct LumiSettingsTabItem: Identifiable {
    /// Unique identifier, typically the plugin's info ID.
    public let id: String
    /// Display title shown in the settings sidebar.
    public let title: String
    /// SF Symbol name for the sidebar icon.
    public let systemImage: String
    /// Closure that creates the tab content view on demand.
    private let contentBuilder: @MainActor () -> AnyView

    /// Creates a new settings tab item.
    /// - Parameters:
    ///   - id: Unique identifier for this tab.
    ///   - title: Display title.
    ///   - systemImage: SF Symbol icon name.
    ///   - content: A view builder that produces the tab content.
    public init(
        id: String,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping @MainActor () -> some View
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.contentBuilder = { AnyView(content()) }
    }

    /// Builds the tab content view.
    public func makeContent() -> AnyView {
        contentBuilder()
    }
}
