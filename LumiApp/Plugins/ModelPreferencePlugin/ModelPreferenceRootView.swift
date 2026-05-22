import SwiftUI
import os

/// 模型偏好根视图包裹器
///
/// 功能：
/// 1. 启动时恢复当前对话的聊天模式
/// 2. 对话切换时恢复新对话的聊天模式
/// 3. 模型偏好由模型选择器直接保存到 Conversation，不再同步到全局 AppLLMVM
@MainActor
struct ModelPreferenceRootView<Content: View>: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static var emoji: String { "🎯" }
    /// 是否输出详细日志
    nonisolated static var verbose: Bool { ModelPreferencePlugin.verbose }
    /// 专用 Logger
    nonisolated static var logger: Logger {
        ModelPreferencePlugin.logger
    }

    let content: Content

    @EnvironmentObject var llmVM: AppLLMVM
    @EnvironmentObject var conversationVM: WindowConversationVM

    @State private var hasAppeared = false
    // 标记是否正在加载配置，避免加载时触发保存
    @State private var isLoadingConfig = false

    var body: some View {
        content
            .onChange(of: conversationVM.selectedConversationId) { oldId, newId in
                handleConversationChange(oldId: oldId, newId: newId)
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                // 首次加载：恢复当前对话的配置
                restoreConfigOnStartup()
            }
            .onDisappear {
                isLoadingConfig = false
            }
    }

    // MARK: - 启动恢复

    /// 首次启动时恢复当前对话的配置
    private func restoreConfigOnStartup() {
        isLoadingConfig = true

        // 恢复聊天模式偏好
        if let chatModePref = conversationVM.getChatModePreference() {
            applyChatModeConfig(chatMode: chatModePref, source: "对话")
        } else {
            if Self.verbose {
                Self.logger.info("\(self.t)🔄 启动时无对话聊天模式偏好，保持 AppLLMVM 默认值")
            }
        }

        isLoadingConfig = false
    }

    // MARK: - 对话切换处理

    /// 处理对话切换
    private func handleConversationChange(oldId: UUID?, newId: UUID?) {
        isLoadingConfig = true

        // 恢复聊天模式偏好
        if let chatModePref = conversationVM.getChatModePreference() {
            applyChatModeConfig(chatMode: chatModePref, source: "对话")
        } else if Self.verbose {
            Self.logger.info("\(self.t)🔄 切换对话时无对话聊天模式偏好，保持 AppLLMVM 当前值")
        }

        isLoadingConfig = false
    }

    // MARK: - 辅助方法

    /// 将聊天模式配置应用到 AppLLMVM
    private func applyChatModeConfig(chatMode: ChatMode, source: String) {
        llmVM.setChatMode(chatMode)

        if Self.verbose {
            Self.logger.info("\(self.t)📂 已加载 \(source) 的聊天模式偏好：\(chatMode.rawValue)")
        }
    }
}
