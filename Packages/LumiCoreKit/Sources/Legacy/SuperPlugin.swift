import SwiftUI

/// Legacy plugin protocol retained for Editor extension packages.
/// New Lumi features should use ``LumiPlugin`` instead.
public protocol SuperPlugin: AnyObject {
    static var id: String { get }
    static var displayName: String { get }
    static var description: String { get }
    static var iconName: String { get }
    static var order: Int { get }
    static var category: PluginCategory { get }
    static var policy: PluginPolicy { get }
    nonisolated var instanceLabel: String { get }
}

public extension SuperPlugin {
    nonisolated var instanceLabel: String { Self.id }

    nonisolated var providesEditorExtensions: Bool { false }

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor func configureRuntime(context: PluginRuntimeContext) {}

    @MainActor func addRailItems(context: PluginContext) -> [RailItem] { [] }
    @MainActor func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] { [] }
    @MainActor func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? { nil }
    @MainActor func addPanelHeaderView(context: PluginContext) -> AnyView? { nil }
    @MainActor func addPosterViews() -> [AnyView] { [] }
}
