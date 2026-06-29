import SwiftUI

/// Where a plugin-contributed settings tab appears in the sidebar.
public enum LumiSettingsTabSidebarPlacement: Sendable, Equatable {
    /// After the core tabs, below the separator.
    case pluginSection
    /// Inline with core tabs, immediately after the given core tab raw value.
    case inlineAfterCore(String)
}

/// A settings tab contributed by a plugin to appear in the app Settings sidebar.
///
/// Plugins return instances of this model from `addSettingsTabs(context:)` to
/// register their own top-level settings entries alongside core tabs like
/// General, Appearance, and Plugins.
@MainActor
public struct LumiSettingsTabItem: Identifiable {
    /// Unique identifier, typically the plugin's info ID.
    public let id: String
    /// Display title shown in the settings sidebar.
    public let title: String
    /// SF Symbol name for the sidebar icon.
    public let systemImage: String
    /// Sidebar placement relative to core tabs.
    public let sidebarPlacement: LumiSettingsTabSidebarPlacement
    /// Closure that creates the tab content view on demand.
    private let contentBuilder: @MainActor () -> AnyView

    /// Creates a new settings tab item.
    /// - Parameters:
    ///   - id: Unique identifier for this tab.
    ///   - title: Display title.
    ///   - systemImage: SF Symbol icon name.
    ///   - sidebarPlacement: Where the tab appears in the sidebar.
    ///   - content: A view builder that produces the tab content.
    public init(
        id: String,
        title: String,
        systemImage: String,
        sidebarPlacement: LumiSettingsTabSidebarPlacement = .pluginSection,
        @ViewBuilder content: @escaping @MainActor () -> some View
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.sidebarPlacement = sidebarPlacement
        self.contentBuilder = { AnyView(content()) }
    }

    /// Builds the tab content view.
    public func makeContent() -> AnyView {
        contentBuilder()
    }
}
