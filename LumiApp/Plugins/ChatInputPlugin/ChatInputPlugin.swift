import SwiftUI
import os

/// 聊天输入插件
///
/// 负责右侧栏的输入区域 Section，包括文本编辑器和命令建议。
///
/// 发送控制、待发送消息、模型选择器、附件、截图等能力由独立插件注入。
actor ChatInputPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-input")

    nonisolated static let emoji = "⌨️"
    nonisolated static let verbose: Bool = true
    static let id = "ChatInput"
    static let displayName = String(localized: "Chat Input", table: "ChatInputPlugin")
    static let description = String(localized: "Chat input area with editor and command suggestions", table: "ChatInputPlugin")
    static let iconName = "keyboard"
    static var category: PluginCategory { .agent }
    static var order: Int { 96 }
    nonisolated static let enable: Bool = true
    static let shared = ChatInputPlugin()

    // MARK: - UI Contributions

    /// 右侧栏 Section：输入区域
    @MainActor func addSidebarSections(activeIcon: String?) -> [AnyView] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [AnyView(InputView())]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
