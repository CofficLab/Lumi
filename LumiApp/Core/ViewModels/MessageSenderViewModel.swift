import Foundation
import MagicKit
import OSLog

/// 消息发送回调
/// 用于解耦 MessageSenderViewModel 和 AgentProvider
@MainActor
protocol MessageSendingDelegate: AnyObject, Sendable {
    /// 开始处理消息
    func messageSendingDidStart()
    
    /// 结束处理消息
    func messageSendingDidFinish()
    
    /// 处理用户消息
    /// - Parameters:
    ///   - content: 消息内容
    ///   - images: 图片附件
    func processUserMessage(content: String, images: [ImageAttachment]) async
}

/// 消息发送队列 ViewModel
/// 负责管理待发送消息队列，按顺序逐个发送消息
@MainActor
final class MessageSenderViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = true  // 开启日志以便调试

    // MARK: - 服务依赖

    /// 消息管理 ViewModel
    private let messageViewModel: MessageViewModel
    /// 会话管理 ViewModel
    private let conversationViewModel: ConversationViewModel
    /// 聊天历史服务
    private let chatHistoryService: ChatHistoryService
    /// LLM 配置提供者
    private weak var configProvider: (any LLMConfigProvider)?
    /// Slash 命令服务
    private let slashCommandService: SlashCommandService

    // MARK: - 回调委托

    /// 消息发送委托
    weak var delegate: (any MessageSendingDelegate)?

    // MARK: - 发送状态

    /// 当前会话 ID（用于隔离队列）
    @Published public fileprivate(set) var currentConversationId: UUID?

    /// 待发送消息队列字典（按会话 ID 隔离）
    /// 每个会话都有自己独立的待发送队列
    private var pendingMessagesByConversation: [UUID: [ChatMessage]] = [:]

    /// 当前会话的待发送消息队列（包括正在发送的消息）
    @Published public fileprivate(set) var pendingMessages: [ChatMessage] = []

    /// 当前正在处理的消息索引（nil 表示没有正在处理的消息）
    @Published public fileprivate(set) var currentProcessingIndex: Int?

    /// 是否正在发送消息
    @Published public fileprivate(set) var isSending: Bool = false

    /// 取消标记
    private var isCancelled: Bool = false

    /// 发送任务队列（后台执行）
    private var sendTask: Task<Void, Never>?

    // MARK: - 初始化

    init(
        messageViewModel: MessageViewModel,
        conversationViewModel: ConversationViewModel,
        chatHistoryService: ChatHistoryService,
        slashCommandService: SlashCommandService,
        configProvider: (any LLMConfigProvider)? = nil
    ) {
        self.messageViewModel = messageViewModel
        self.conversationViewModel = conversationViewModel
        self.chatHistoryService = chatHistoryService
        self.slashCommandService = slashCommandService
        self.configProvider = configProvider
    }

    /// 设置 LLM 配置提供者
    func setConfigProvider(_ provider: any LLMConfigProvider) {
        self.configProvider = provider
    }

    // MARK: - 会话管理

    /// 切换到指定会话
    /// - Parameter conversationId: 会话 ID
    /// - Returns: 切换后队列中的消息数量
    @discardableResult
    func switchToConversation(_ conversationId: UUID) -> Int {
        // 保存当前会话状态（如果有）
        if let currentId = currentConversationId {
            if Self.verbose {
                let count = pendingMessagesByConversation[currentId]?.count ?? 0
                os_log("\(Self.t)💾 保存会话 [{\(currentId.uuidString.prefix(8))}] 队列状态：\(count) 条消息")
            }
        }

        // 切换到新会话
        currentConversationId = conversationId

        // 如果新会话没有队列，创建空队列
        if pendingMessagesByConversation[conversationId] == nil {
            pendingMessagesByConversation[conversationId] = []
        }

        pendingMessages = pendingMessagesByConversation[conversationId] ?? []

        let queueCount = pendingMessages.count

        if Self.verbose {
            os_log("\(Self.t)🔄 切换到会话 [{\(conversationId.uuidString.prefix(8))}]，队列长度：\(queueCount)")
        }

        return queueCount
    }

    /// 清空当前会话的发送队列
    func clearCurrentConversationQueue() {
        guard let conversationId = currentConversationId else { return }
        pendingMessagesByConversation[conversationId]?.removeAll()
        currentProcessingIndex = nil

        // 强制触发 @Published 通知
        objectWillChange.send()
        pendingMessages = []

        if Self.verbose {
            os_log("\(Self.t)🗑️ 已清空当前会话 [{\(conversationId.uuidString.prefix(8))}] 的发送队列")
        }
    }

    /// 获取指定会话的队列消息数量
    func getQueueCount(for conversationId: UUID) -> Int {
        pendingMessagesByConversation[conversationId]?.count ?? 0
    }

    // MARK: - 公开方法

    /// 发送用户消息
    /// - Parameters:
    ///   - content: 消息内容
    ///   - images: 图片附件（可选）
    ///   - onComplete: 发送完成回调
    func sendMessage(
        content: String,
        images: [ImageAttachment] = [],
        onComplete: (() -> Void)? = nil
    ) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // 使用选中的会话 ID 获取会话
        guard let conversationId = conversationViewModel.selectedConversationId,
              let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            os_log(.error, "\(Self.t)❌ 当前没有活动对话")
            return
        }

        // 确保当前会话 ID 与活动对话一致
        if currentConversationId != conversation.id {
            switchToConversation(conversation.id)
        }

        // 创建用户消息
        let userMessage = ChatMessage(role: .user, content: content, images: images)

        // 添加到待发送队列
        pendingMessagesByConversation[conversation.id, default: []].append(userMessage)

        // 同步更新 pendingMessages，触发 UI 更新
        let updatedMessages = pendingMessagesByConversation[conversation.id, default: []]
        objectWillChange.send()
        pendingMessages = updatedMessages

        os_log("\(Self.t)📝 消息已加入队列（队列长度：\(self.pendingMessages.count)）：\(content.max(50))")

        // 启动或继续队列处理
        startOrContinueProcessing()
    }

    /// 启动或继续处理队列
    private func startOrContinueProcessing() {
        // 如果已经在处理中，新消息会自动留在队列中等待处理
        guard !isSending else {
            os_log("\(Self.t)⏳ 已有消息在处理中，新消息已在队列中等待")
            return
        }

        // 队列为空则退出
        guard !pendingMessages.isEmpty else { return }

        os_log("\(Self.t)🚀 启动队列处理，当前队列长度：\(self.pendingMessages.count)")

        // 在后台线程启动发送流程
        sendTask?.cancel()
        sendTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.processQueue()
        }
    }

    /// 处理消息队列
    private func processQueue() async {
        os_log("\(Self.t)🔄 processQueue 开始执行")

        // 标记开始处理
        await MainActor.run {
            isSending = true
            isCancelled = false
            delegate?.messageSendingDidStart()
        }

        // 持续处理队列中的消息
        while !isCancelled {
            // 获取下一条消息
            var nextMessage: ChatMessage? = nil
            
            await MainActor.run {
                if !self.pendingMessages.isEmpty {
                    self.currentProcessingIndex = 0
                    nextMessage = self.pendingMessages.first
                    os_log("\(Self.t)📥 取出消息，队列剩余：\(self.pendingMessages.count)")
                }
            }

            // 队列为空，结束处理
            guard let message = nextMessage else {
                os_log("\(Self.t)📭 队列为空，结束处理")
                break
            }

            os_log("\(Self.t)📤 开始发送消息：\(message.content.max(30))...")

            // 发送消息
            await sendMessageToAgent(message: message)

            // 检查是否被取消
            if isCancelled {
                os_log("\(Self.t)🛑 处理被取消")
                break
            }

            // 移除已处理的消息
            await MainActor.run {
                guard let conversationId = self.currentConversationId else { return }
                // 检查队列是否为空，避免崩溃
                guard !self.pendingMessagesByConversation[conversationId, default: []].isEmpty else {
                    os_log("\(Self.t)⚠️ 队列已空，跳过移除操作")
                    return
                }
                self.pendingMessagesByConversation[conversationId]?.removeFirst()
                // 同步更新 pendingMessages，触发 UI 更新
                let updatedMessages = self.pendingMessagesByConversation[conversationId] ?? []
                self.objectWillChange.send()
                self.pendingMessages = updatedMessages
                os_log("\(Self.t)🗑️ 移除已处理消息，队列剩余：\(self.pendingMessages.count)")
                self.currentProcessingIndex = nil
            }
        }

        // 标记处理完成
        await MainActor.run {
            isSending = false
            currentProcessingIndex = nil
            delegate?.messageSendingDidFinish()
            os_log("\(Self.t)✅ 队列处理完成，剩余消息：\(self.pendingMessages.count)")
        }
    }

    /// 发送单条消息到 Agent
    private func sendMessageToAgent(message: ChatMessage) async {
        let remaining = await MainActor.run { self.pendingMessages.count - 1 }
        os_log("\(Self.t)📤 正在发送（剩余 \(remaining) 条等待）：\(message.content.max(50))")

        // 在主线程添加用户消息到列表
        await MainActor.run {
            messageViewModel.appendMessageInternal(message)
        }
        
        // 保存到数据库
        conversationViewModel.saveMessage(message)

        // 启动会话标题生成（如果需要）
        startConversationTitleGenerationIfNeeded(message: message)

        // 处理消息（等待完成）
        await delegate?.processUserMessage(content: message.content, images: message.images)

        os_log("\(Self.t)✅ 消息发送完成：\(message.content.max(30))...")
    }

    /// 启动会话标题生成（如果需要）
    /// 只提取必要参数，在后台 Task 中执行，不阻塞当前流程
    private func startConversationTitleGenerationIfNeeded(message: ChatMessage) {
        // 只处理用户消息
        guard message.role == .user else { return }

        // 获取当前对话 ID
        guard let conversationId = conversationViewModel.selectedConversationId else { return }

        // 获取会话以检查标题
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else { return }

        // 检查是否满足生成标题的条件（快速检查，避免不必要的后台任务）
        guard conversation.title.hasPrefix("新会话 "),
              !messageViewModel.hasGeneratedTitle else {
            return
        }

        // 标记已生成标题，防止重复生成
        messageViewModel.setHasGeneratedTitleInternal(true)

        // 获取 LLM 配置
        let config = configProvider?.getCurrentConfig() ?? LLMConfig.default
        
        // 消息内容和 ID
        let messageContent = message.content
        let chatHistoryService = self.chatHistoryService

        // 在后台 Task 中执行标题生成
        Task.detached(priority: .utility) {
            await chatHistoryService.autoGenerateConversationTitleIfNeeded(
                conversationId: conversationId,
                userMessageContent: messageContent,
                config: config
            )
        }
    }

    /// 取消当前任务并清空队列
    func cancelAll() {
        isCancelled = true
        clearCurrentConversationQueue()
        isSending = false
        sendTask?.cancel()
        sendTask = nil

        os_log("\(Self.t)🛑 已取消当前会话所有待发送消息")
    }

    /// 清空发送队列（仅清除等待中的消息）
    func clearQueue() {
        // 只清除等待中的消息，保留正在发送的消息
        guard let conversationId = currentConversationId else { return }

        if currentProcessingIndex != nil, pendingMessages.count > 1 {
            pendingMessagesByConversation[conversationId] = Array(pendingMessages.prefix(1))
        } else if currentProcessingIndex == nil {
            pendingMessagesByConversation[conversationId]?.removeAll()
        }

        // 同步更新 pendingMessages，触发 UI 更新
        let updatedMessages = pendingMessagesByConversation[conversationId] ?? []
        objectWillChange.send()
        pendingMessages = updatedMessages

        os_log("\(Self.t)🗑️ 发送队列已清空")
    }

    /// 获取队列中的消息数量
    func queueCount() -> Int {
        pendingMessages.count
    }

    /// 判断队列是否为空
    func isQueueEmpty() -> Bool {
        pendingMessages.isEmpty
    }
    
    /// 移除队列中指定位置的消息
    func removeMessage(at index: Int) {
        // 不能移除正在发送的消息
        guard index != currentProcessingIndex else { return }
        guard let conversationId = currentConversationId else { return }
        guard pendingMessages.indices.contains(index) else { return }
        // 检查数组是否为空，避免崩溃
        guard !pendingMessagesByConversation[conversationId, default: []].isEmpty else { return }

        pendingMessagesByConversation[conversationId]?.remove(at: index)

        // 同步更新 pendingMessages，触发 UI 更新
        let updatedMessages = pendingMessagesByConversation[conversationId] ?? []
        objectWillChange.send()
        pendingMessages = updatedMessages

        // 更新当前处理索引
        if let currentIdx = currentProcessingIndex, index < currentIdx {
            currentProcessingIndex = currentIdx - 1
        }

        os_log("\(Self.t)🗑️ 已移除队列中的第 \(index) 条消息")
    }

    /// 清空所有会话的发送队列（用于完全重置）
    func clearAllQueues() {
        pendingMessagesByConversation.removeAll()
        currentProcessingIndex = nil
        isSending = false
        isCancelled = true
        sendTask?.cancel()
        sendTask = nil

        os_log("\(Self.t)🗑️ 所有会话的发送队列已清空")
    }

    /// 删除指定会话的发送队列（用于删除会话时清理）
    func removeConversationQueue(_ conversationId: UUID) {
        pendingMessagesByConversation.removeValue(forKey: conversationId)

        if Self.verbose {
            os_log("\(Self.t)🗑️ 已删除会话 [{\(conversationId.uuidString.prefix(8))}] 的发送队列")
        }
    }
}
