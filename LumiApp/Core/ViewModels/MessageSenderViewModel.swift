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
    nonisolated static let verbose = false

    // MARK: - 服务依赖

    /// 消息管理 ViewModel
    private let messageViewModel: MessageViewModel
    /// 会话管理 ViewModel
    private let conversationViewModel: ConversationViewModel
    /// 聊天历史服务
    private let chatHistoryService: ChatHistoryService
    /// LLM 配置提供者
    private weak var configProvider: (any LLMConfigProvider)?

    // MARK: - 回调委托

    /// 消息发送委托
    weak var delegate: (any MessageSendingDelegate)?

    // MARK: - 发送状态

    /// 待发送消息队列（包括正在发送的消息）
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
        configProvider: (any LLMConfigProvider)? = nil
    ) {
        self.messageViewModel = messageViewModel
        self.conversationViewModel = conversationViewModel
        self.chatHistoryService = chatHistoryService
        self.configProvider = configProvider
    }

    /// 设置 LLM 配置提供者
    func setConfigProvider(_ provider: any LLMConfigProvider) {
        self.configProvider = provider
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

        guard conversationViewModel.currentConversation != nil else {
            os_log(.error, "\(Self.t)❌ 当前没有活动对话")
            return
        }

        // 创建用户消息
        let userMessage = ChatMessage(role: .user, content: content, images: images)

        // 添加到待发送队列
        pendingMessages.append(userMessage)

        if Self.verbose {
            os_log("\(Self.t)📝 消息已加入队列（队列长度：\(self.pendingMessages.count)）：\(content.max(50))")
        }

        // 启动或继续队列处理
        startOrContinueProcessing()
    }

    /// 启动或继续处理队列
    private func startOrContinueProcessing() {
        // 如果已经在处理中，新消息会自动留在队列中等待处理
        guard !isSending else {
            if Self.verbose {
                os_log("\(Self.t)⏳ 已有消息在处理中，新消息已在队列中等待")
            }
            return
        }

        // 队列为空则退出
        guard !pendingMessages.isEmpty else { return }

        // 在后台线程启动发送流程
        sendTask?.cancel()
        sendTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.processQueue()
        }
    }

    /// 处理消息队列
    private func processQueue() async {
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
                }
            }

            // 队列为空，结束处理
            guard let message = nextMessage else { break }

            // 发送消息
            await sendMessageToAgent(message: message)

            // 检查是否被取消
            if isCancelled { break }

            // 移除已处理的消息
            await MainActor.run {
                if !self.pendingMessages.isEmpty {
                    self.pendingMessages.removeFirst()
                }
                self.currentProcessingIndex = nil
            }
        }

        // 标记处理完成
        await MainActor.run {
            isSending = false
            currentProcessingIndex = nil
            delegate?.messageSendingDidFinish()
        }
    }

    /// 发送单条消息到 Agent
    private func sendMessageToAgent(message: ChatMessage) async {
        if Self.verbose {
            let remaining = await MainActor.run { self.pendingMessages.count - 1 }
            os_log("\(Self.t)📤 正在发送（剩余 \(remaining) 条等待）：\(message.content.max(50))")
        }

        // 在主线程添加用户消息到列表
        await MainActor.run {
            messageViewModel.appendMessageInternal(message)
        }
        
        // 保存到数据库
        conversationViewModel.saveMessage(message)

        // 启动会话标题生成 Job（如果需要）
        startConversationTitleGenerationJob(message: message)

        // 处理消息（等待完成）
        await delegate?.processUserMessage(content: message.content, images: message.images)

        if Self.verbose {
            os_log("\(Self.t)✅ 消息发送完成")
        }
    }

    /// 启动会话标题生成 Job
    /// 只提取必要参数，在后台 Task 中执行，不阻塞当前流程
    private func startConversationTitleGenerationJob(message: ChatMessage) {
        // 只处理用户消息
        guard message.role == .user else { return }

        // 获取当前对话 ID
        guard let conversationId = conversationViewModel.currentConversation?.id else { return }
        
        // 检查是否满足生成标题的条件（快速检查，避免不必要的后台任务）
        guard conversationViewModel.currentConversation?.title.hasPrefix("新会话 ") == true,
              !conversationViewModel.hasGeneratedTitle else {
            return
        }

        // 标记已生成标题，防止重复生成
        conversationViewModel.setHasGeneratedTitleInternal(true)

        // 获取 LLM 配置
        let config = configProvider?.getCurrentConfig() ?? LLMConfig.default
        
        // 消息内容和 ID
        let messageContent = message.content
        let messageId = message.id
        let chatHistoryService = self.chatHistoryService

        // 在后台 Task 中执行标题生成
        Task.detached(priority: .utility) {
            let job = ConversationTitleGenerationJob()
            await job.run(
                conversationId: conversationId,
                messageId: messageId,
                userMessageContent: messageContent,
                config: config,
                chatHistoryService: chatHistoryService
            )
        }
    }

    /// 取消当前任务并清空队列
    func cancelAll() {
        isCancelled = true
        pendingMessages.removeAll()
        isSending = false
        currentProcessingIndex = nil
        sendTask?.cancel()
        sendTask = nil

        if Self.verbose {
            os_log("\(Self.t)🛑 已取消所有待发送消息")
        }
    }

    /// 清空发送队列（仅清除等待中的消息）
    func clearQueue() {
        // 只清除等待中的消息，保留正在发送的消息
        if currentProcessingIndex != nil, pendingMessages.count > 1 {
            pendingMessages = Array(pendingMessages.prefix(1))
        } else if currentProcessingIndex == nil {
            pendingMessages.removeAll()
        }

        if Self.verbose {
            os_log("\(Self.t)🗑️ 发送队列已清空")
        }
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
        guard pendingMessages.indices.contains(index) else { return }
        
        pendingMessages.remove(at: index)
        
        // 更新当前处理索引
        if let currentIdx = currentProcessingIndex, index < currentIdx {
            currentProcessingIndex = currentIdx - 1
        }
        
        if Self.verbose {
            os_log("\(Self.t)🗑️ 已移除队列中的第 \(index) 条消息")
        }
    }
}