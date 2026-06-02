import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// 聊天输入插件
///
/// 负责右侧栏的输入区域 Section，包括文本编辑器和命令建议。
///
/// 发送控制、待发送消息、模型选择器、附件、截图等能力由独立插件注入。
public actor ChatInputPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-input")

    public nonisolated static let emoji = "⌨️"
    public nonisolated static let verbose: Bool = true
    public static let id = "ChatInput"
    public static let displayName = String(localized: "Chat Input", table: "ChatInputPlugin")
    public static let description = String(localized: "Chat input area with editor and command suggestions", table: "ChatInputPlugin")
    public static let iconName = "keyboard"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 96 }
    public static let shared = ChatInputPlugin()

    // MARK: - UI Contributions

    /// 右侧栏 Section：输入区域
    @MainActor public func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.supportsAIChat else { return [] }
        return [AnyView(InputView())]
    }
}
