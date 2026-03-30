import Foundation
import MagicKit
import SwiftUI

/// 当前选中会话在 UI 中的消息列表
@MainActor
final class MessagePendingVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

    /// 当前会话的消息列表
    @Published public fileprivate(set) var messages: [ChatMessage] = []

    init() {}

    /// 追加消息
    func appendMessage(_ message: ChatMessage) {
        messages.append(message)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📝 追加 1 条消息，当前共 \(self.messages.count) 条")
        }
    }

    /// 插入消息
    func insertMessage(_ message: ChatMessage, at index: Int) {
        messages.insert(message, at: index)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📝 insertMessageInternal: 在位置 \(index) 插入消息，当前共 \(self.messages.count) 条")
        }
    }

    /// 更新消息
    func updateMessage(_ message: ChatMessage, at index: Int) {
        // 创建新数组以触发 SwiftUI 更新
        var updatedMessages = messages
        updatedMessages[index] = message
        messages = updatedMessages

        if Self.verbose {
            let suffixLen = 80
            let contentSuffix = message.content.count <= suffixLen
                ? message.content
                : String(message.content.suffix(suffixLen))
            var parts: [String] = [
                "位置 \(index)",
                "长度 \(message.content.count)",
                "role=\(message.role)",
                "isError=\(message.isError)",
                "结尾: …\(contentSuffix)"
            ]
            if let p = message.providerId { parts.append("provider=\(p)") }
            if let m = message.modelName { parts.append("model=\(m)") }
            if let n = message.toolCalls?.count, n > 0 { parts.append("toolCalls=\(n)") }
            if let ms = message.latency { parts.append("latency=\(Int(ms))ms") }
            if let t = message.totalTokens { parts.append("tokens=\(t)") }
            else if let i = message.inputTokens, let o = message.outputTokens { parts.append("in=\(i) out=\(o)") }
            else if let o = message.outputTokens { parts.append("outTokens=\(o)") }
            else if let i = message.inputTokens { parts.append("inTokens=\(i)") }
            if message.isTransientStatus { parts.append("transient") }
            AppLogger.core.info("\(Self.t)🍋 更新消息: \(parts.joined(separator: ", "))")
        }
    }
}
