import MagicKit
import SwiftUI
import os

actor InputPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input-manager")

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

    /// 该面板不需要右侧栏
    
    @MainActor
    func addPanelView() -> AnyView? {
        AnyView(InputSettingsView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
