import Foundation
import LumiCoreLLMProvider
import LumiCoreMessage
import LumiKernel
import os
import SuperLogKit

/// Mock implementation of `MessageSendManaging`.
///
/// Responsibilities (per `MessageSendManaging` contract):
/// 1. Trim `content`; return early on empty input.
/// 2. Resolve the target conversation:
///    - `conversationID` if non-nil,
///    - else `kernel.conversations?.selectedConversationID`,
///    - else throw `LumiKernelError.noActiveConversation`.
/// 3. Insert a `LumiChatMessage(role: .user, ...)` via
///    `kernel.messageManager?.insertMessage(_:to:)`.
///
/// Out of scope (placeholder behavior for now):
/// - No LLM call is made.
/// - No assistant reply is generated.
/// - `isSending` flips true → false synchronously; the field exists for
///   the UI to read but does not yet reflect long-running work.
@MainActor
public final class MockMessageSendManager: MessageSendManaging, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-send-manager.mock")
    public nonisolated static let emoji = "📤"
    nonisolated static let verbose = true

    @Published public private(set) var isSending: Bool = false

    private weak var kernel: LumiKernel?

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)MockMessageSendManager (kernel=\(String(describing: ObjectIdentifier(kernel))))")
        }
    }

    public func sendMessage(_ content: String, conversationID: UUID?) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)sendMessage 开始 ➡️ conversationID=\(conversationID?.uuidString ?? "nil"), content.len=\(content.count)")
        }

        // 1. Trim & early-return on empty input
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(Self.t)sendMessage ➡️ content 空白，直接返回")
            }
            return
        }

        // 2. Resolve target conversation
        let targetID: UUID
        if let conversationID {
            targetID = conversationID
            if Self.verbose {
                Self.logger.info("\(Self.t)解析目标会话 ➡️ 使用显式 conversationID=\(targetID.uuidString.prefix(8))…")
            }
        } else if let selected = kernel?.conversations?.selectedConversationID {
            targetID = selected
            if Self.verbose {
                Self.logger.info("\(Self.t)解析目标会话 ➡️ 使用 selectedConversationID=\(targetID.uuidString.prefix(8))…")
            }
        } else {
            if Self.verbose {
                Self.logger.error("\(Self.t)sendMessage 失败 ➡️ 没有可用的 conversationID，也没有 selectedConversationID")
            }
            throw LumiKernelError.noActiveConversation
        }

        // 3. Persist user message into the message history
        isSending = true
        if Self.verbose {
            Self.logger.info("\(Self.t)isSending -> true, 准备写入 user 消息到会话 \(targetID.uuidString.prefix(8))…")
        }
        defer {
            isSending = false
            if Self.verbose {
                Self.logger.info("\(Self.t)isSending -> false, sendMessage 结束")
            }
        }

        let userMessage = LumiChatMessage(
            conversationID: targetID,
            role: .user,
            content: trimmed
        )
        kernel?.messageManager?.insertMessage(userMessage, to: targetID)
        if Self.verbose {
            Self.logger.info("\(Self.t)user 消息已落库 ➡️ id=\(userMessage.id.uuidString.prefix(8))…, content.len=\(trimmed.count)")
        }

        // 4. Hand off the full conversation history to the first
        //    available LLM provider; the returned assistant message is
        //    persisted back into the message history.
        guard let kernel else { return }
        let history = kernel.messageManager?.messages(for: targetID) ?? []
        guard let provider = kernel.llmProvider?.allLLMProviders().first else {
            if Self.verbose {
                Self.logger.error("\(Self.t)sendMessage ➡️ 内核没有 LLM provider, 抛 llmProviderUnavailable")
            }
            throw LumiKernelError.llmProviderUnavailable
        }
        let model = type(of: provider).info.defaultModel
        let request = LumiLLMRequest(messages: history, model: model)
        if Self.verbose {
            Self.logger.info("\(Self.t)sendMessage ➡️ 调 LLM provider id=\(type(of: provider).info.id), model=\(model), messages=\(history.count)")
        }
        let assistantMessage = try await kernel.llmProvider!.sendToFirstProvider(request)
        kernel.messageManager?.insertMessage(assistantMessage, to: targetID)
        if Self.verbose {
            Self.logger.info("\(Self.t)assistant 消息已落库 ➡️ id=\(assistantMessage.id.uuidString.prefix(8))…, content.len=\(assistantMessage.content.count)")
        }
    }

    public func cancelCurrentRequest() {
        if isSending {
            isSending = false
            if Self.verbose {
                Self.logger.info("\(Self.t)cancelCurrentRequest ➡️ isSending -> false")
            }
        } else if Self.verbose {
            Self.logger.info("\(Self.t)cancelCurrentRequest ➡️ 当前无 in-flight 发送, no-op")
        }
    }
}
