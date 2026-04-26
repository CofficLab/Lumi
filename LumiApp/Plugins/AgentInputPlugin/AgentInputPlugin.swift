import MagicKit
import SwiftUI
import os

/// Agent 输入插件 - 负责显示输入区域（编辑器、工具栏等）
///
/// 注意：输入区域（InputView）已整合到 EditorPlugin 的右侧聊天栏中。
/// 本插件保留仅用于维护输入相关的 ViewModel、模型选择器等组件。
/// 实际 UI 渲染由 EditorPlugin 的 ChatSidebarView 负责。
actor AgentInputPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input")

    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = false
    static let id = "AgentInput"
    static let displayName = String(localized: "Agent Input", table: "AgentInput")
    static let description = String(localized: "Agent input area", table: "AgentInput")
    static let iconName = "textformat.abc"
    static var order: Int { 83 }
    nonisolated static let enable: Bool = true
    static let shared = AgentInputPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        // Init
    }

    nonisolated func onEnable() {
        // Init
    }

    nonisolated func onDisable() {
        // Cleanup
    }
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
