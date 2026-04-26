import Foundation
import SwiftUI
import os
import MagicKit

/// Quick File Search Plugin: 快速文件搜索插件
///
/// 功能：通过 Cmd+P 快捷键触发悬浮文件搜索框，快速定位和选择项目中的文件
actor QuickFileSearchPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.quick-file-search")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔍"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = false

    static let id = "QuickFileSearch"
    static let displayName = String(localized: "Quick File Search", table: "QuickFileSearch")
    static let description = String(localized: "Fast file search with Cmd+P", table: "QuickFileSearch")
    static let iconName = "magnifyingglass"
    nonisolated static let isConfigurable: Bool = false
    static var order: Int { 50 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = QuickFileSearchPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 QuickFileSearchPlugin 已注册")
        }
    }

    nonisolated func onEnable() {
        Task { @MainActor in
            FileSearchHotkeyManager.shared.startMonitoring()
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ QuickFileSearchPlugin 已启用，快捷键监听已启动")
        }
    }

    nonisolated func onDisable() {
        Task { @MainActor in
            FileSearchHotkeyManager.shared.stopMonitoring()
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)⛔️ QuickFileSearchPlugin 已禁用")
        }
    }

    // MARK: - UI Contributions

    /// 提供根视图包裹层
    /// 包含悬浮搜索框的 ZStack overlay
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(FileSearchOverlay(content: content()))
    }

    /// 提供设置视图
    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(QuickFileSearchSettingsView())
    }

    @MainActor
    func agentTools() -> [AgentTool] { [] }

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] { [] }

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] { [] }
}

// MARK: - Preview

#Preview("File Search Overlay") {
    FileSearchOverlay(content: Text("Content"))
        .inRootView()
}
