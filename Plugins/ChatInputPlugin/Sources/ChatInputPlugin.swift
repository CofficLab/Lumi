import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// 聊天输入插件
///
/// 负责右侧栏的输入区域 Section，包括文本编辑器和命令建议。
///
/// 发送控制、待发送消息、模型选择器、附件、截图等能力由独立插件注入。
public actor ChatInputPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-input")

    public nonisolated static let emoji = "⌨️"
    public nonisolated static let verbose: Bool = true
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "keyboard"

    public static let info = LumiPluginInfo(
        id: "ChatInput",
        displayName: LumiPluginLocalization.string("Chat Input", bundle: .module),
        description: LumiPluginLocalization.string("Chat input area with editor and command suggestions", bundle: .module),
        order: 96
    )

    @MainActor
    public func addSidebarSections(context: PluginContext) -> [AnyView] {
        []
    }

    @MainActor
    public func addSidebarBottomSections(context: PluginContext) -> [AnyView] {
        guard context.showChat.isVisible else { return [] }
        return [AnyView(InputView())]
    }
}
