import SwiftUI

actor InputPlugin: SuperPlugin {
    nonisolated static let id = "input-manager"
    nonisolated static let name = "Input Manager"
    nonisolated static let iconName = "keyboard"
    nonisolated static let displayName = String(localized: "Input Manager")
    nonisolated static let navigationId = "InputManager"
    static var order: Int { 70 }
    
    // Initialize service on plugin load
    init() {
        // Ensure service is started
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
        .hideTabPicker()
        .withNavigation(InputPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
