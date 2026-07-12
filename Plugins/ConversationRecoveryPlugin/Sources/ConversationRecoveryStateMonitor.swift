import Foundation
import LumiCoreKit
import LumiChatKit
import os

/// 对话恢复状态监控器
///
/// 监听对话变化，检测被中断的对话并维护中断状态。
/// 参考 AutoTask 插件的 TurnCheckRuntime 实现模式。
@MainActor
public final class ConversationRecoveryStateMonitor: ObservableObject {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-recovery")

    // MARK: - Singleton

    public static let shared = ConversationRecoveryStateMonitor()

    // MARK: - Published State

    /// 当前检测到的中断对话列表
    @Published public private(set) var interruptedConversations: [LumiConversationInterruption] = []

    // MARK: - Private State

    private var messageObserver: NSObjectProtocol?
    private var turnObserver: NSObjectProtocol?
    private var chatService: ChatService?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 启动监控
    ///
    /// 监听消息保存和 turn 结束通知，检测中断情况。
    public func startMonitoring(chatService: ChatService) {
        self.chatService = chatService

        // 监听消息保存（检测流式中断和错误状态）
        messageObserver = NotificationCenter.default.addObserver(
            forName: .lumiMessageSaved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                await self?.handleMessageSaved(notification)
            }
        }

        // 监听 turn 结束（检测工具未完成和 turn 未正常完成）
        turnObserver = NotificationCenter.default.addObserver(
            forName: .lumiTurnFinished,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                await self?.handleTurnFinished(notification)
            }
        }

        // 启动时扫描所有对话
        scanAllConversations()
    }

    /// 停止监控
    public func stopMonitoring() {
        if let observer = messageObserver {
            NotificationCenter.default.removeObserver(observer)
            messageObserver = nil
        }
        if let observer = turnObserver {
            NotificationCenter.default.removeObserver(observer)
            turnObserver = nil
        }
        chatService = nil
    }

    /// 手动刷新中断检测
    public func refresh() {
        scanAllConversations()
    }

    /// 标记对话为已恢复
    public func markRecovered(conversationID: UUID) {
        interruptedConversations.removeAll { $0.conversationID == conversationID }
    }

    /// 获取指定对话的中断信息
    public func getInterruption(for conversationID: UUID) -> LumiConversationInterruption? {
        interruptedConversations.first { $0.conversationID == conversationID }
    }

    // MARK: - Private Methods

    private func handleMessageSaved(_ notification: Notification) {
        guard let conversationID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID else {
            return
        }

        // 重新检测该对话的中断状态
        updateInterruption(for: conversationID)
    }

    private func handleTurnFinished(_ notification: Notification) {
        guard let conversationID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID,
              let reason = notification.userInfo?[LumiTurnFinishedNotification.reasonKey] as? String else {
            return
        }

        // 如果 turn 正常完成，清除中断状态
        if reason == LumiTurnEndReason.completed.rawValue {
            interruptedConversations.removeAll { $0.conversationID == conversationID }
            return
        }

        // 如果 turn 失败或取消，检测中断状态
        updateInterruption(for: conversationID)
    }

    private func scanAllConversations() {
        guard let chatService else { return }

        // 获取所有对话的消息
        var messagesByConversation: [UUID: [LumiChatMessage]] = [:]
        for conversation in chatService.conversations {
            messagesByConversation[conversation.id] = chatService.messages(for: conversation.id)
        }

        // 使用检测器扫描
        let interruptions = LumiConversationInterruptionDetector.detectInterruptedConversations(
            in: messagesByConversation
        )

        interruptedConversations = interruptions
    }

    private func updateInterruption(for conversationID: UUID) {
        guard let chatService else { return }

        let messages = chatService.messages(for: conversationID)
        let interruption = LumiConversationInterruptionDetector.detectInterruption(
            conversationID: conversationID,
            messages: messages
        )

        // 更新中断列表
        if let interruption {
            // 添加或更新中断信息
            interruptedConversations.removeAll { $0.conversationID == conversationID }
            interruptedConversations.append(interruption)
        } else {
            // 清除中断信息
            interruptedConversations.removeAll { $0.conversationID == conversationID }
        }
    }
}
