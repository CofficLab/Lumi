import SwiftUI
import AppKit
import Foundation
import os

/// 快速启动器插件：提供系统常见应用的快捷入口
actor QuickLauncherPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.quicklauncher")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🚀"

    nonisolated static let verbose: Bool = true

    static let id: String = "QuickLauncher"
    static let navigationId: String = "quicklauncher_settings"
    static let displayName: String = String(localized: "Quick Launcher", table: "QuickLauncher")
    static let description: String = String(localized: "Quick access to system apps and utilities", table: "QuickLauncher")
    static let iconName: String = "app.grid"
    static var category: PluginCategory { .system }
    static var order: Int { 8 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = QuickLauncherPlugin()

    // MARK: - UI Contributions

    @MainActor
    func addPosterViews() -> [AnyView] {
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
    @MainActor func addMenuBarPopupView() -> AnyView? {
        AnyView(QuickLauncherMenuBarPopupView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
