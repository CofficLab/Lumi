import SwiftUI
import MagicKit
import os

/// 模型偏好根视图包裹器
///
/// 功能：
/// 1. 启动时恢复当前对话的模型配置和聊天模式
/// 2. 对话切换时恢复新对话的模型配置和聊天模式
/// 3. 监听模型变化作为兜底保存（应对 ensureProviderAndModelSelection 等自动修正场景）
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

    // 用于记录之前的模型配置，避免重复保存
    @State private var lastSavedProvider: String = ""
    @State private var lastSavedModel: String = ""
    @State private var lastSavedConversationId: UUID?
    @State private var hasAppeared = false
    // 标记是否正在加载配置，避免加载时触发保存
    @State private var isLoadingConfig = false

    var body: some View {
        content
            .onChange(of: llmVM.selectedProviderId) { _, _ in
                handleModelChange()
            }
            .onChange(of: llmVM.currentModel) { _, _ in
                handleModelChange()
            }
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

        // 恢复模型偏好
        if let conversationPref = conversationVM.getModelPreference() {
            applyConfig(provider: conversationPref.providerId, model: conversationPref.model, source: "对话")
        } else {
            // 无对话偏好，保持 AppLLMVM 默认值
            if Self.verbose {
                Self.logger.info("\(self.t)🔄 启动时无对话模型偏好，保持 AppLLMVM 默认值")
            }
        }

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

    // MARK: - 模型变化处理

    /// 处理模型变化：作为兜底保存到当前对话
    ///
    /// ModelSelectorView.selectModel() 和 SwitchModelTool 已直接保存，
    /// 此处应对 ensureProviderAndModelSelection 等自动修正场景。
    private func handleModelChange() {
        let currentProvider = llmVM.selectedProviderId
        let currentModel = llmVM.currentModel
        let currentConversationId = conversationVM.selectedConversationId

        // 只在有有效值时保存
        guard !currentProvider.isEmpty,
              !currentModel.isEmpty else {
            return
        }

        // 如果正在加载配置，不要触发保存
        guard !isLoadingConfig else {
            return
        }

        // 避免重复保存相同的配置
        if currentProvider == lastSavedProvider,
           currentModel == lastSavedModel,
           currentConversationId == lastSavedConversationId {
            return
        }

        // 保存到当前对话
        conversationVM.saveModelPreference(providerId: currentProvider, model: currentModel)

        // 更新最后保存的状态
        lastSavedProvider = currentProvider
        lastSavedModel = currentModel
        lastSavedConversationId = currentConversationId

        if Self.verbose {
            if Self.verbose {
                Self.logger.info("\(self.t)💾 已保存对话模型偏好：\(currentProvider) - \(currentModel)")
            }
        }
    }

    // MARK: - 对话切换处理

    /// 处理对话切换
    private func handleConversationChange(oldId: UUID?, newId: UUID?) {
        isLoadingConfig = true

        // 清除上次保存的记录，确保新对话可以正常保存
        lastSavedConversationId = nil

        // 恢复模型偏好
        if let newId,
           let conversation = conversationVM.fetchConversation(id: newId),
           let providerId = conversation.providerId,
           let model = conversation.model {
            applyConfig(provider: providerId, model: model, source: "对话[\(conversation.title)]")
        } else {
            // 保持 AppLLMVM 当前值（默认配置）
            if Self.verbose {
                Self.logger.info("\(self.t)🔄 切换对话时无对话模型偏好，保持 AppLLMVM 当前值")
            }
            lastSavedProvider = llmVM.selectedProviderId
            lastSavedModel = llmVM.currentModel
        }

        // 恢复聊天模式偏好
        if let chatModePref = conversationVM.getChatModePreference() {
            applyChatModeConfig(chatMode: chatModePref, source: "对话")
        } else if Self.verbose {
            Self.logger.info("\(self.t)🔄 切换对话时无对话聊天模式偏好，保持 AppLLMVM 当前值")
        }

        isLoadingConfig = false
    }

    // MARK: - 辅助方法

    /// 将模型配置应用到 AppLLMVM，并更新去重状态
    private func applyConfig(provider: String, model: String, source: String) {
        llmVM.selectedProviderId = provider
        llmVM.currentModel = model

        // 更新去重状态，避免 onChange 触发重复保存
        lastSavedProvider = provider
        lastSavedModel = model
        lastSavedConversationId = conversationVM.selectedConversationId

        if Self.verbose {
            Self.logger.info("\(self.t)📂 已加载 \(source) 的模型偏好：\(provider) - \(model)")
        }
    }

    /// 将聊天模式配置应用到 AppLLMVM
    private func applyChatModeConfig(chatMode: ChatMode, source: String) {
        llmVM.setChatMode(chatMode)

        if Self.verbose {
            Self.logger.info("\(self.t)📂 已加载 \(source) 的聊天模式偏好：\(chatMode.rawValue)")
        }
    }
}
