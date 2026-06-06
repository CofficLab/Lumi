import SwiftUI
import LumiCoreKit
import LumiUI
import SuperLogKit
import AppKit
import Foundation
import os

/// 快速启动器插件：提供系统常见应用的快捷入口
public actor QuickLauncherPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.quicklauncher")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "🚀"

    public nonisolated static let verbose: Bool = false

    public static let id: String = "QuickLauncher"
    public static let navigationId: String = "quicklauncher_settings"
    public static let displayName: String = String(localized: "Quick Launcher", bundle: .module)
    public static let description: String = String(localized: "Quick access to system apps and utilities", bundle: .module)
    public static let iconName: String = "app.grid"
    public static var category: PluginCategory { .system }
    public static var order: Int { 8 }

    // MARK: - Instance

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = QuickLauncherPlugin()

    // MARK: - UI Contributions

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "快速启动器",
                subtitle: "从菜单栏快速打开系统应用和常用工具。",
                icon: Self.iconName,
                accent: .orange,
                metrics: [
                    PluginPosterSupport.metric("Apps", "应用"),
                    PluginPosterSupport.metric("Menu", "菜单栏"),
                ],
                rows: ["系统应用", "实用工具", "菜单栏入口"],
                chips: ["启动器", "菜单栏", "系统"]
            ),
        ]
    }

    /// 添加菜单栏弹窗视图
    /// - Returns: 要添加到菜单栏弹窗的视图，如果不需要则返回nil
    @MainActor public func addMenuBarPopupView() -> AnyView? {
        AnyView(QuickLauncherMenuBarPopupView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
