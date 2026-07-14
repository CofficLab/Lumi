// MARK: - Conversation Plugins Imports
import Foundation
import LumiCoreKit
import ConversationLanguagePlugin
import ConversationListPlugin
import ConversationNewPlugin
import ConversationForkPlugin
import ConversationTimelinePlugin
import ConversationTitlePlugin
import ChatModePlugin
import VerbosityPlugin

// MARK: - Conversation Plugins Extension

extension LumiPluginRegistry {
    /// Conversation 插件数组，包含所有会话管理相关的插件。
    ///
    /// 包含：会话标题、时间线、语言、模式、列表、新建、分支
    public static let conversationPlugins: [any LumiPlugin.Type] = [
        // MARK: - Core

        ConversationTitlePlugin.self,
        ConversationTimelinePlugin.self,
        ConversationLanguagePlugin.self,
        ChatModePlugin.self,
        VerbosityPlugin.self,

        // MARK: - List & Actions

        ConversationListPlugin.self,
        ConversationNewPlugin.self,
        ConversationForkPlugin.self,
    ]
}
