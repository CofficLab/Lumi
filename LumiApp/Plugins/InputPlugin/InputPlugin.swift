import MagicKit
import SwiftUI

actor InputPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "⌨️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id = "InputManager"
    static let navigationId: String = "input_manager"
    static let displayName = String(localized: "Input Manager", table: "Input")
    static let description = String(localized: "Manage input-related behaviors", table: "Input")
    static let iconName = "keyboard"
    static let isConfigurable: Bool = false
    static var order: Int { 70 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = InputPlugin()
    
    init() {
        Task { @MainActor in
            _ = InputService.shared
        }
    }
    
    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                InputSettingsView()
            }
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(InputPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
