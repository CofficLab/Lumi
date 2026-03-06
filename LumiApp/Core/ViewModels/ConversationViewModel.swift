import Foundation
import MagicKit
import SwiftUI
import OSLog
import SwiftData

/// 会话管理 ViewModel
/// 负责处理所有会话相关的业务逻辑，包括创建、加载、删除会话等
@MainActor
final class ConversationViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

    // MARK: - 服务依赖

    /// 聊天历史服务
    private let chatHistoryService: ChatHistoryService

    /// LLM 服务（用于生成会话标题）
    private let llmService: LLMService

    /// 提示词服务（用于获取欢迎消息）
    private let promptService: PromptService

    /// 消息管理 ViewModel
    let messageViewModel: MessageViewModel

    /// 消息发送队列 ViewModel（用于会话切换时同步队列）
    weak var messageSenderViewModel: MessageSenderViewModel?

    // MARK: - 会话状态

    /// 当前会话
    @Published public fileprivate(set) var currentConversation: Conversation?

    /// 选中的会话 ID
    @Published public fileprivate(set) var selectedConversationId: UUID? {
        didSet {
            if let id = selectedConversationId {
                UserDefaults.standard.set(id.uuidString, forKey: "Conversation_SelectedId")
            } else {
                UserDefaults.standard.removeObject(forKey: "Conversation_SelectedId")
            }
        }
    }

    // MARK: - 代理 MessageViewModel 属性

    /// 当前会话的消息列表（代理到 MessageViewModel）
    public var messages: [ChatMessage] {
        messageViewModel.messages
    }

    /// 标记是否已生成标题（代理到 MessageViewModel）
    public var hasGeneratedTitle: Bool {
        messageViewModel.hasGeneratedTitle
    }

    // MARK: - 内部方法（仅供 AgentProvider 使用）

    /// 设置当前会话（内部使用）
    func setCurrentConversationInternal(_ conversation: Conversation?) {
        currentConversation = conversation
    }

    // MARK: - 代理 MessageViewModel 方法

    /// 设置消息列表（内部使用）
    func setMessagesInternal(_ newMessages: [ChatMessage]) {
        messageViewModel.setMessagesInternal(newMessages)
    }

    /// 追加消息（内部使用）
    func appendMessageInternal(_ message: ChatMessage) {
        messageViewModel.appendMessageInternal(message)
    }

    /// 插入消息（内部使用）
    func insertMessageInternal(_ message: ChatMessage, at index: Int) {
        messageViewModel.insertMessageInternal(message, at: index)
    }

    /// 更新消息（内部使用）
    func updateMessageInternal(_ message: ChatMessage, at index: Int) {
        messageViewModel.updateMessageInternal(message, at: index)
    }

    /// 设置标题生成标记（内部使用）
    func setHasGeneratedTitleInternal(_ value: Bool) {
        messageViewModel.setHasGeneratedTitleInternal(value)
    }

    // MARK: - 初始化

    /// 使用依赖服务初始化
    init(
        chatHistoryService: ChatHistoryService,
        llmService: LLMService = LLMService.shared,
        promptService: PromptService = PromptService.shared,
        messageViewModel: MessageViewModel,
        messageSenderViewModel: MessageSenderViewModel? = nil
    ) {
        self.chatHistoryService = chatHistoryService
        self.llmService = llmService
        self.promptService = promptService
        self.messageViewModel = messageViewModel
        self.messageSenderViewModel = messageSenderViewModel
    }

    // MARK: - 会话管理

    /// 创建新对话
    /// - Parameters:
    ///   - projectId: 关联的项目 ID（可选，nil 表示全局对话）
    ///   - title: 对话标题（默认为"新会话"）
    /// - Returns: 新创建的对话
    func createConversation(projectId: String? = nil, title: String = "新会话") -> Conversation {
        if Self.verbose {
            os_log("\(Self.t)🚀 开始创建新会话")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let newConversation = chatHistoryService.createConversation(
            projectId: projectId,
            title: title + " " + formatter.string(from: Date())
        )

        // 切换到新会话的队列
        messageSenderViewModel?.switchToConversation(newConversation.id)

        messageViewModel.setHasGeneratedTitleInternal(false)

        if Self.verbose {
            os_log("\(Self.t)✅ [\(newConversation.id)] 新会话创建完成")
        }

        return newConversation
    }

    /// 创建新对话（异步版本，支持设置当前会话）
    /// - Parameters:
    ///   - projectId: 关联的项目 ID（可选，nil 表示全局对话）
    ///   - projectName: 项目名称（可选，用于生成欢迎消息）
    ///   - projectPath: 项目路径（可选，用于生成欢迎消息）
    ///   - language: 语言偏好（默认为中文）
    func createNewConversation(
        projectId: String? = nil,
        projectName: String? = nil,
        projectPath: String? = nil,
        language: LanguagePreference = .chinese
    ) async {
        let newConversation = createConversation(projectId: projectId)
        currentConversation = newConversation
        selectedConversationId = newConversation.id

        // 获取欢迎消息并保存到数据库
        let welcomeMessage = await promptService.getEmptySessionWelcomeMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: language,
            conversationId: newConversation.id
        )

        if !welcomeMessage.isEmpty {
            let welcomeMsg = ChatMessage(role: .assistant, content: welcomeMessage)
            if let savedMessage = chatHistoryService.saveMessage(welcomeMsg, to: newConversation) {
                messageViewModel.setMessagesInternal([savedMessage])
            }
        }
    }

    /// 加载指定对话的消息
    /// - Parameter conversationId: 对话 ID
    func loadConversation(_ conversationId: UUID) async {
        if Self.verbose {
            os_log("\(Self.t)📥 [\(conversationId)] 开始加载对话")
        }

        // 从数据库获取对话
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            os_log(.error, "\(Self.t)❌ [\(conversationId)] 对话不存在")
            return
        }

        // 切换消息发送队列到新会话
        if let senderVM = messageSenderViewModel {
            let queueCount = senderVM.switchToConversation(conversation.id)
            if Self.verbose {
                os_log("\(Self.t)🔄 切换到会话队列，待发送消息：\(queueCount) 条")
            }
        }

        currentConversation = conversation
        _ = messageViewModel.loadMessages(for: conversation)

        if Self.verbose {
            os_log("\(Self.t)✅ [\(conversation.id)] 对话加载完成，共 \(self.messages.count) 条消息")
        }
    }

    /// 保存消息到当前对话
    /// - Parameter message: 要保存的消息
    func saveMessage(_ message: ChatMessage) {
        guard let conversation = currentConversation else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 当前没有活动对话，跳过保存")
            }
            return
        }

        chatHistoryService.saveMessage(message, to: conversation)

        if Self.verbose {
            os_log("\(Self.t)💾 [\(conversation.id)] 消息已保存：\(message.content.max(50))")
        }
    }

    /// 删除指定对话
    /// - Parameter conversation: 要删除的对话
    func deleteConversation(_ conversation: Conversation) {
        os_log("\(Self.t)🗑️ 开始删除对话：\(conversation.title)")

        // 如果删除的是当前对话，清理状态
        if currentConversation?.id == conversation.id {
            currentConversation = nil
            messageViewModel.clearMessages()
            // 清理该会话的待发送队列
            messageSenderViewModel?.clearCurrentConversationQueue()
        }

        // 如果删除的是选中的对话，清除选中状态
        if selectedConversationId == conversation.id {
            selectedConversationId = nil
        }

        // 清理该会话的待发送队列（即使不是当前对话）
        messageSenderViewModel?.removeConversationQueue(conversation.id)

        chatHistoryService.deleteConversation(conversation)

        os_log("\(Self.t)✅ 对话已删除：\(conversation.title)")
    }

    /// 更新对话标题
    /// - Parameters:
    ///   - conversation: 要更新的对话
    ///   - newTitle: 新标题
    func updateConversationTitle(_ conversation: Conversation, newTitle: String) {
        chatHistoryService.updateConversationTitle(conversation, newTitle: newTitle)

        if Self.verbose {
            os_log("\(Self.t)✏️ 对话标题已更新：\(newTitle)")
        }
    }

    /// 基于第一条消息生成会话标题
    /// - Parameters:
    ///   - userMessage: 用户的第一条消息
    ///   - config: LLM 配置
    func generateConversationTitle(from userMessage: String, config: LLMConfig) async -> String {
        await chatHistoryService.generateConversationTitle(from: userMessage, config: config)
    }

    // MARK: - 会话选择

    /// 选择指定会话
    /// - Parameter id: 会话 ID
    func selectConversation(_ id: UUID) {
        selectedConversationId = id
    }

    /// 清除会话选择
    func clearConversationSelection() {
        selectedConversationId = nil
        currentConversation = nil
        messageViewModel.clearMessages()
    }

    /// 恢复上次选择的会话
    /// - Parameter modelContext: 数据上下文（用于验证会话是否存在）
    func restoreSelectedConversation(modelContext: ModelContext?) {
        guard let savedId = UserDefaults.standard.string(forKey: "Conversation_SelectedId"),
              let uuid = UUID(uuidString: savedId) else {
            return
        }

        // 如果有 modelContext，验证会话是否存在
        if let context = modelContext {
            let descriptor = FetchDescriptor<Conversation>(
                predicate: #Predicate { $0.id == uuid }
            )

            do {
                let conversations = try context.fetch(descriptor)
                if conversations.isEmpty {
                    // 会话已不存在，清除保存的 ID
                    if Self.verbose {
                        os_log("\(Self.t)⚠️ 上次选择的会话已不存在，清除保存状态")
                    }
                    UserDefaults.standard.removeObject(forKey: "Conversation_SelectedId")
                    return
                }
                // 会话存在，恢复选择
                selectedConversationId = uuid
                if Self.verbose {
                    os_log("\(Self.t)✅ [\(uuid)] 已恢复会话")
                }
            } catch {
                os_log(.error, "\(Self.t)❌ 验证会话失败：\(error.localizedDescription)")
            }
        } else {
            // 没有 modelContext，直接恢复（可能在初始化阶段）
            selectedConversationId = uuid
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 已恢复会话选择（未验证）: \(uuid)")
            }
        }
    }

    // MARK: - 获取会话列表

    /// 获取所有对话
    func fetchAllConversations() -> [Conversation] {
        chatHistoryService.fetchAllConversations()
    }

    /// 获取项目相关的对话
    /// - Parameter projectId: 项目路径
    /// - Returns: 项目相关的对话列表
    func fetchConversations(forProject projectId: String) -> [Conversation] {
        chatHistoryService.fetchConversations(forProject: projectId)
    }
}
