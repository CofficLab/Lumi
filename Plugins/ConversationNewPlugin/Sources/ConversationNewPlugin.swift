import LumiCoreKit
import SwiftUI

/// 新建对话头部插件
///
/// 在工具栏右侧提供新建对话按钮（NewChatButton）。
public actor ConversationNewPlugin: SuperPlugin {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let id = "AgentChatToolbar"
    public static let displayName = String(localized: "New Chat Button", bundle: .module)
    public static let description = String(localized: "Create new chat from header", bundle: .module)
    public static let iconName = "bubble.left.and.bubble.right"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 60 }
    
    /// 核心功能按钮，禁止用户配置
    
    public static let shared = ConversationNewPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - Toolbar Views

    /// 工具栏右侧：新建对话按钮
    @MainActor
    public func addToolBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.showChat.isVisible else { return nil }
        return AnyView(NewChatButton(context: context))
    }
}
