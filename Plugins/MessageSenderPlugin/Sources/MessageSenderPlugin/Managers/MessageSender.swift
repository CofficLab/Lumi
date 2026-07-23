import Foundation
import LumiKernel
import LumiKernel
import LumiKernel
import os
import SuperLogKit

/// Default implementation of `MessageSending`.
///
/// Responsibilities (per `MessageSending` contract):
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
public final class MessageSender: MessageSending, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-send-manager.service")
    public nonisolated static let emoji = "📤"
    nonisolated static let verbose = false

    @Published public private(set) var isSending: Bool = false

    /// 当前挂起、等待下次发送时随消息一起送出的图片附件。
    /// `addAttachment / removeAttachment / clearAttachments` 维护此集合。
    @Published public private(set) var pendingAttachments: [LumiImageAttachment] = []

    /// 当前挂起、等待下次发送时随消息一起送出的**文件**附件(与图片并行的链路)。
    /// `addFileAttachment / removeFileAttachment / clearFileAttachments` 维护此集合。
    @Published public private(set) var pendingFileAttachments: [LumiFileAttachment] = []

    private weak var kernel: LumiKernel?

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)MessageSendManager (kernel=\(String(describing: ObjectIdentifier(kernel))))")
        }
    }

    // MARK: - 附件挂起池

    /// 添加附件。幂等:同 `id` 已存在则忽略。
    public func addAttachment(_ attachment: LumiImageAttachment) {
        guard !pendingAttachments.contains(where: { $0.id == attachment.id }) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)addAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))… 已存在,忽略")
            }
            return
        }
        pendingAttachments.append(attachment)
        if Self.verbose {
            Self.logger.info("\(Self.t)addAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))…, mime=\(attachment.mimeType), pool.size=\(self.pendingAttachments.count)")
        }
    }

    /// 按 id 移除挂起附件。id 不存在则 no-op。
    public func removeAttachment(id: UUID) {
        let before = pendingAttachments.count
        pendingAttachments.removeAll { $0.id == id }
        if Self.verbose {
            Self.logger.info("\(Self.t)removeAttachment ➡️ id=\(id.uuidString.prefix(8))…, before=\(before), after=\(self.pendingAttachments.count)")
        }
    }

    /// 清空所有挂起附件。
    public func clearAttachments() {
        let count = pendingAttachments.count
        pendingAttachments.removeAll()
        if Self.verbose {
            Self.logger.info("\(Self.t)clearAttachments ➡️ cleared \(count) items")
        }
    }

    // MARK: - 文件附件挂起池

    /// 添加文件附件。幂等:同 `id` 已存在则忽略。
    public func addFileAttachment(_ attachment: LumiFileAttachment) {
        guard !pendingFileAttachments.contains(where: { $0.id == attachment.id }) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)addFileAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))… 已存在,忽略")
            }
            return
        }
        pendingFileAttachments.append(attachment)
        if Self.verbose {
            Self.logger.info("\(Self.t)addFileAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))…, name=\(attachment.fileName), pool.size=\(self.pendingFileAttachments.count)")
        }
    }

    /// 按 id 移除挂起文件附件。id 不存在则 no-op。
    public func removeFileAttachment(id: UUID) {
        let before = pendingFileAttachments.count
        pendingFileAttachments.removeAll { $0.id == id }
        if Self.verbose {
            Self.logger.info("\(Self.t)removeFileAttachment ➡️ id=\(id.uuidString.prefix(8))…, before=\(before), after=\(self.pendingFileAttachments.count)")
        }
    }

    /// 清空所有挂起文件附件。
    public func clearFileAttachments() {
        let count = pendingFileAttachments.count
        pendingFileAttachments.removeAll()
        if Self.verbose {
            Self.logger.info("\(Self.t)clearFileAttachments ➡️ cleared \(count) items")
        }
    }

    // MARK: - 发送

    public func sendMessage(_ content: String, conversationID: UUID?) async throws {
        // 委托给带 attachments 的重载,使用当前挂起池快照。
        try await sendMessage(
            content,
            imageAttachments: pendingAttachments,
            conversationID: conversationID
        )
    }

    public func sendMessage(
        _ content: String,
        imageAttachments: [LumiImageAttachment],
        conversationID: UUID?
    ) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)sendMessage 开始 ➡️ conversationID=\(conversationID?.uuidString ?? "nil"), content.len=\(content.count), attachments=\(imageAttachments.count)")
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

        // 把 attachments 序列化进 metadata["imageAttachments"] JSON(如有)
        var metadata: [String: String] = [:]
        if !imageAttachments.isEmpty {
            do {
                let data = try JSONEncoder().encode(imageAttachments)
                metadata["imageAttachments"] = String(data: data, encoding: .utf8) ?? ""
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)sendMessage ➡️ 编码 attachments 失败: \(error.localizedDescription)")
                }
            }
        }

        // 把文件附件序列化进 metadata["fileAttachments"] JSON(如有)。
        // 文件链路与图片并行:取当前文件挂起池快照,文本类文件正文在下游注入用户消息。
        if !pendingFileAttachments.isEmpty {
            metadata = LumiFileAttachmentMetadata.encode(pendingFileAttachments, into: metadata)
        }

        let userMessage = LumiChatMessage(
            conversationID: targetID,
            role: .user,
            content: trimmed,
            metadata: metadata
        )
        kernel?.messageManager?.insertMessage(userMessage, to: targetID)
        if Self.verbose {
            Self.logger.info("\(Self.t)user 消息已落库 ➡️ id=\(userMessage.id.uuidString.prefix(8))…, content.len=\(trimmed.count), attachments=\(imageAttachments.count)")
        }

        // 4. Delegate to AgentTurnRunner to execute the full agent loop.
        guard let kernelInstance = kernel else {
            isSending = false
            return
        }

        do {
            try await kernelInstance.agentTurnRunner?.runTurn(in: targetID)
            if Self.verbose {
                Self.logger.info("\(Self.t)agentTurnRunner.runTurn 完成")
            }
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)sendMessage ➡️ agentTurnRunner 抛出 error: \(error.localizedDescription)")
            }
            // Insert error message into conversation
            let errorMessage = LumiChatMessage(
                conversationID: targetID,
                role: .error,
                content: error.localizedDescription
            )
            kernelInstance.messageManager?.insertMessage(errorMessage, to: targetID)
            if Self.verbose {
                Self.logger.info("\(Self.t)error 消息已落库 ➡️ id=\(errorMessage.id.uuidString.prefix(8))…")
            }
        }

        // 5. Clean up sending state (after turn completes)
        isSending = false
        // 附件已在步骤 3 序列化进消息 metadata,与该消息绑定;回合期间 AgentTurnRunner
        // 从 metadata(而非挂起池)读取附件,故此处可安全清空预览池,避免发送后残留。
        clearAttachments()
        clearFileAttachments()
        if Self.verbose {
            Self.logger.info("\(Self.t)isSending -> false, sendMessage 结束")
        }
    }

    public func cancelCurrentRequest() {
        if isSending {
            isSending = false
            // Cancel the agent turn if one is running
            if let conversationID = kernel?.conversations?.selectedConversationID {
                kernel?.agentTurnRunner?.cancelTurn(in: conversationID)
            }
            if Self.verbose {
                Self.logger.info("\(Self.t)cancelCurrentRequest ➡️ isSending -> false, turn cancelled")
            }
        } else if Self.verbose {
            Self.logger.info("\(Self.t)cancelCurrentRequest ➡️ 当前无 in-flight 发送, no-op")
        }
    }
}
