import Foundation
import LumiKernel
import LumiKernel
import LumiKernel
import os
import SuperLogKit

/// Default implementation of `MessageSendManaging`.
///
/// Responsibilities (per `MessageSendManaging` contract):
/// 1. Trim `content`; return early on empty input.
/// 2. Resolve the target conversation:
///    - `conversationID` if non-nil,
///    - else `kernel.conversations?.selectedConversationID`,
///    - else throw `LumiKernelError.noActiveConversation`.
/// 3. Insert a `LumiChatMessage(role: .user, ...)` via
///    `kernel.messageManager?.insertMessage(_:to:)`.
/// 4. Hand the full conversation history to the first registered
///    LLM provider via `kernel.llmProvider?.sendToFirstProvider(_:)`,
///    using that provider's `defaultModel` for the request. Insert
///    the returned assistant message back into the message history.
///
/// `isSending` flips true → false around steps 3-4 via `defer`, so it
/// always settles back to `false` whether the call completes or throws.
@MainActor
public final class MessageSendManager: MessageSendManaging, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-send-manager.service")
    public nonisolated static let emoji = "📤"
    nonisolated static let verbose = true

    @Published public private(set) var isSending: Bool = false

    private weak var kernel: LumiKernel?
    /// Tracks the status message ID for each conversation to replace it with the final response
    private var statusMessageIDByConversation: [UUID: UUID] = [:]

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)MessageSendManager (kernel=\(String(describing: ObjectIdentifier(kernel))))")
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
            // No conversation selected - auto-create one
            if Self.verbose {
                Self.logger.info("\(Self.t)解析目标会话 ➡️ 没有选中对话，自动创建新对话")
            }
            guard let newID = try? kernel?.conversations?.createConversation(title: nil) else {
                if Self.verbose {
                    Self.logger.error("\(Self.t)sendMessage 失败 ➡️ 创建对话失败")
                }
                throw LumiKernelError.noActiveConversation
            }
            targetID = newID
            if Self.verbose {
                Self.logger.info("\(Self.t)自动创建对话成功 ➡️ id=\(targetID.uuidString.prefix(8))…")
            }
        }

        // 3. Persist user message into the message history
        isSending = true
        if Self.verbose {
            Self.logger.info("\(Self.t)isSending -> true, 准备写入 user 消息到会话 \(targetID.uuidString.prefix(8))…")
        }
        defer {
            isSending = false
            // Clear status message on completion
            if let statusID = statusMessageIDByConversation[targetID] {
                kernel?.messageManager?.deleteMessage(id: statusID, in: targetID)
                statusMessageIDByConversation[targetID] = nil
            }
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

        // Insert status message to show sending state
        let statusID = UUID()
        statusMessageIDByConversation[targetID] = statusID
        let statusMessage = LumiChatMessage(
            id: statusID,
            conversationID: targetID,
            role: .status,
            content: "正在发送消息…",
            metadata: ["isTransientStatus": "true"]
        )
        kernel?.messageManager?.insertMessage(statusMessage, to: targetID)
        if Self.verbose {
            Self.logger.info("\(Self.t)status 消息已落库 ➡️ id=\(statusID.uuidString.prefix(8))…")
        }

        // 4. Hand off the full conversation history to the selected
        //    LLM provider; the returned assistant message is
        //    persisted back into the message history.
        guard let kernel else { return }
        let history = kernel.messageManager?.messages(for: targetID) ?? []
        guard let provider = kernel.llmProvider?.allLLMProviders().first else {
            if Self.verbose {
                Self.logger.error("\(Self.t)sendMessage ➡️ 内核没有 LLM provider, 抛 llmProviderUnavailable")
            }
            throw LumiKernelError.llmProviderUnavailable
        }
        let model = kernel.llmProvider?.selectedModel ?? type(of: provider).info.defaultModel
        let tools = kernel.toolManager?.allAgentTools() ?? []
        let request = LumiLLMRequest(messages: history, model: model, tools: tools)
        if Self.verbose {
            Self.logger.info("\(Self.t)sendMessage ➡️ 调 LLM provider, model=\(model), messages=\(history.count), tools=\(tools.count)")
        }

        do {
            let assistantMessage = try await kernel.llmProvider!.sendToSelectedProvider(request)
            kernel.messageManager?.insertMessage(assistantMessage, to: targetID)
            if Self.verbose {
                Self.logger.info("\(Self.t)assistant 消息已落库 ➡️ id=\(assistantMessage.id.uuidString.prefix(8))…, content.len=\(assistantMessage.content.count)")
            }
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)sendMessage ➡️ provider 抛出 error: \(error.localizedDescription)")
            }
            // Insert error message into conversation
            let errorMessage = LumiChatMessage(
                conversationID: targetID,
                role: .error,
                content: error.localizedDescription
            )
            kernel.messageManager?.insertMessage(errorMessage, to: targetID)
            if Self.verbose {
                Self.logger.info("\(Self.t)error 消息已落库 ➡️ id=\(errorMessage.id.uuidString.prefix(8))…")
            }
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
