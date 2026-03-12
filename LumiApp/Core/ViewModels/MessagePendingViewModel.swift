import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

/// 消息管理 ViewModel
/// 负责处理所有消息相关的业务逻辑，包括加载、保存、追加、更新、删除消息等
@MainActor
final class MessageViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = true

    // MARK: - 服务依赖

    /// 聊天历史服务
    private let chatHistoryService: ChatHistoryService

    // MARK: - 消息状态

    /// 当前会话的消息列表
    @Published public fileprivate(set) var messages: [ChatMessage] = []

    // MARK: - 初始化

    /// 使用聊天历史服务初始化
    init(chatHistoryService: ChatHistoryService) {
        self.chatHistoryService = chatHistoryService
    }

    /// 设置消息列表
    /// - Parameters:
    ///   - newMessages: 新的消息列表
    ///   - reason: 设置消息列表的原因
    func setMessages(_ newMessages: [ChatMessage], reason: String) {
        let oldCount = messages.count
        messages = newMessages

        if Self.verbose {
            os_log("\(Self.t)📝 (\(reason)) setMessages: \(oldCount) → \(newMessages.count) 条消息")
        }
    }

    /// 追加消息
    func appendMessage(_ message: ChatMessage) {
        messages.append(message)

        if Self.verbose {
            os_log("\(Self.t)📝 appendMessageInternal: 追加 1 条消息，当前共 \(self.messages.count) 条")
        }
    }

    /// 插入消息
    func insertMessage(_ message: ChatMessage, at index: Int) {
        messages.insert(message, at: index)

        if Self.verbose {
            os_log("\(Self.t)📝 insertMessageInternal: 在位置 \(index) 插入消息，当前共 \(self.messages.count) 条")
        }
    }

    /// 更新消息
    func updateMessage(_ message: ChatMessage, at index: Int) {
        // 创建新数组以触发 SwiftUI 更新
        var updatedMessages = messages
        updatedMessages[index] = message
        messages = updatedMessages

        if Self.verbose {
            let contentPreview: String
            if message.content.count > 120 {
                let head = String(message.content.prefix(50))
                let tail = String(message.content.suffix(50))
                contentPreview = "\(head)...\(tail)"
            } else {
                contentPreview = message.content
            }
            let logMessage = "\(Self.t)🍋 更新位置 \(index) 的消息 [\(message.role)] 长度: \(message.content.count) 内容:\n \(contentPreview)"
            os_log("%@", logMessage)
        }
    }
}
