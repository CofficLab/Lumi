import SwiftUI
import LumiUI
import LumiCoreKit
import SuperLogKit
import os

public actor InputPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input-manager")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "⌨️"
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = true

    public static let id = "InputManager"
    public static let navigationId: String = "input_manager"
    public static let displayName = String(localized: "Input Manager", table: "Input")
    public static let description = String(localized: "Manage input-related behaviors", table: "Input")
    public static let iconName = "keyboard"
    public static var order: Int { 70 }
    public nonisolated static let policy: PluginPolicy = .optIn

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = InputPlugin()
    
    public init() {
        Task { @MainActor in
            _ = InputService.shared
        }
    }

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    public func addViewContainer() -> ViewContainerItem? {
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
