import SwiftUI
import os

actor InputPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "⌨️"
    static var category: PluginCategory { .general }
    nonisolated static let verbose: Bool = true

    static let id = "InputManager"
    static let navigationId: String = "input_manager"
    static let displayName = String(localized: "Input Manager", table: "Input")
    static let description = String(localized: "Manage input-related behaviors", table: "Input")
    static let iconName = "keyboard"
    static var order: Int { 70 }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }
    static let shared = InputPlugin()
    
    init() {
        Task { @MainActor in
            _ = InputService.shared
        }
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(InputSettingsView())
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
