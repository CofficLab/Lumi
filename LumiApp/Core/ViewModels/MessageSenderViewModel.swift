import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 消息发送队列 ViewModel
/// 负责管理待发送消息队列，按顺序逐个发送消息
@MainActor
final class MessageSenderViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = false

    /// 全局单例
    static let shared = MessageSenderViewModel()

    // MARK: - 服务依赖

    /// 消息管理 ViewModel
    private let messageViewModel = MessageViewModel.shared
    /// 会话管理 ViewModel
    private let conversationViewModel = ConversationViewModel.shared
    /// 聊天历史服务
    private let chatHistoryService = ChatHistoryService.shared
    /// 智能体提供者
    private let agentProvider = AgentProvider.shared

    // MARK: - 发送状态

    /// 待发送消息队列
    @Published public fileprivate(set) var pendingMessages: [ChatMessage] = []

    /// 是否正在发送消息
    @Published public fileprivate(set) var isSending: Bool = false

    /// 取消标记
    private var isCancelled: Bool = false

    // MARK: - 初始化

    private init() {}

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

        guard let _ = conversationViewModel.currentConversation else {
            os_log(.error, "\(Self.t)❌ 当前没有活动对话")
            return
        }

        // 创建用户消息
        let userMessage = ChatMessage(role: .user, content: content, images: images)

        // 添加到待发送队列
        pendingMessages.append(userMessage)

        if Self.verbose {
            os_log("\(Self.t)📝 消息已加入队列：\(content.max(50))")
        }

        // 启动或继续发送流程
        Task {
            await processQueue()
        }
    }

    /// 处理消息队列
    private func processQueue() async {
        // 防止重入
        guard !isSending else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 已有发送任务在运行")
            }
            return
        }

        // 队列为空则退出
        guard !pendingMessages.isEmpty else {
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 队列为空，无需处理")
            }
            return
        }

        isSending = true
        isCancelled = false

        while !pendingMessages.isEmpty && !isCancelled {
            let message = pendingMessages.removeFirst()
            await sendMessageToAgent(message: message)
        }

        isSending = false
    }

    /// 发送单条消息到 Agent
    private func sendMessageToAgent(message: ChatMessage) async {
        if Self.verbose {
            os_log("\(Self.t)📤 正在发送：\(message.content.max(50))")
        }

        // 立即保存用户消息
        if let conversation = conversationViewModel.currentConversation {
            _ = chatHistoryService.saveMessage(message, to: conversation)
            messageViewModel.appendMessageInternal(message)
        }

        // 通知 AgentProvider 处理消息
        await agentProvider.processUserMessageAsync(content: message.content, images: message.images)

        if Self.verbose {
            os_log("\(Self.t)✅ 消息发送完成")
        }
    }

    /// 取消所有待发送消息
    func cancelAll() {
        isCancelled = true
        pendingMessages.removeAll()
        isSending = false

        if Self.verbose {
            os_log("\(Self.t)🛑 已取消所有待发送消息")
        }
    }

    /// 清空发送队列
    func clearQueue() {
        pendingMessages.removeAll()
        isSending = false
        isCancelled = false

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
}

// MARK: - AgentProvider Extension

extension AgentProvider {
    /// 处理用户消息（内部使用，不重复保存和追加消息）
    @MainActor func processUserMessageAsync(content: String, images: [ImageAttachment]) async {
        let finalContent = content

        let userMsg = ChatMessage(role: .user, content: finalContent, images: images)

        if Self.verbose && !images.isEmpty {
            os_log("\(Self.t)✅ 用户消息包含 \(images.count) 张图片")
        }

        // 消息已由 MessageSenderViewModel 保存和追加
        // 直接处理对话轮次
        await processTurn()
    }
}
