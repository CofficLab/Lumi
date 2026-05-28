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
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "输入行为管理",
                subtitle: "按应用或场景管理输入相关规则。",
                icon: Self.iconName,
                accent: .teal,
                metrics: [
                    PluginPosterSupport.metric("Rules", "规则"),
                    PluginPosterSupport.metric("IME", "输入源"),
                ],
                rows: ["输入源规则", "规则列表", "空状态引导"],
                chips: ["输入法", "规则", "系统"]
            ),
        ]
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
