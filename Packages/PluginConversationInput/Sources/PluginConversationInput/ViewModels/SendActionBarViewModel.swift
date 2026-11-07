import Foundation
import os
import LumiLoggingKit
/// Manages the state and actions for the send/stop action bar.
///
/// The plugin owns this model and its observation lifecycle. Observers update
/// `state` when the input text or sending state changes; the view only renders
/// the model and invokes its actions. All external operations go through
/// `ConversationInputCapability`.
@MainActor
@Observable
final class SendActionBarViewModel: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin-conversation-input", category: "SendActionBarButton")
    nonisolated public static let emoji = "🔘"
    nonisolated static let verbose = true

    private let capability: any ConversationInputCapability

    private(set) var state: SendActionBarState

    // MARK: - Lifecycle

    init(capability: any ConversationInputCapability) {
        self.capability = capability
        self.state = SendActionBarState(
            canStop: capability.canStop(for: capability.selectedConversationID),
            canSend: Self.canSend(
                text: capability.text,
                hasAttachments: !capability.pendingImageAttachments.isEmpty || !capability.pendingFileAttachments.isEmpty
            )
        )
    }

    // MARK: - State updates

    func updateInputText(_ text: String) {
        state.canSend = Self.canSend(
            text: text,
            hasAttachments: !capability.pendingImageAttachments.isEmpty || !capability.pendingFileAttachments.isEmpty
        )
        // - Important: 必须把文本写回能力层。`send()` 直接读 `capability.text`
        //   而不是 `state` 里的副本；若这里只更新 `canSend` 判定，调用方
        //   （直接写入路径，如粘贴、UI 测试的 typeText）点发送时会因为
        //   `capability.text` 仍为空而静默 return——按钮亮着、点了没反应。
        capability.text = text
    }

    func updateAttachments() {
        state.canSend = Self.canSend(
            text: capability.text,
            hasAttachments: !capability.pendingImageAttachments.isEmpty || !capability.pendingFileAttachments.isEmpty
        )
    }

    func refreshConversationState() {
        guard let conversationID = capability.selectedConversationID else {
            state.canStop = false
            return
        }
        state.canStop = capability.canStop(for: conversationID)
    }

    // MARK: - Actions

    /// Cancel the current in-flight request.
    func cancel() {
        capability.cancelCurrentRequest()
        Self.logger.info("\(self.t)cancelled current request")
    }

    /// Send the current input text. Clears the input field on success.
    func send() {
        // 交给发送端的是编辑器原文，而不是预 trim 后的文本：
        // 折叠块区间以原文为基准，预 trim 会让 sender 失去前导空白，
        // 无法把区间平移到 trim 后的正文上。trim 统一由 sender 完成。
        let content = capability.text
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageAttachments = capability.pendingImageAttachments
        let fileAttachments = capability.pendingFileAttachments
        let hasAttachments = !imageAttachments.isEmpty || !fileAttachments.isEmpty
        guard !trimmed.isEmpty || hasAttachments else { return }

        Self.logger.info("\(self.t)sending message, length=\(trimmed.count)")
        // 发送瞬间的折叠块区间。草稿随后被清空，区间也必须同时作废，
        // 否则下一次发送会带上上一条消息的区间。
        let blocks = capability.collapsedBlocks
        capability.text = ""
        capability.errorMessage = nil
        capability.collapsedBlocks = []
        // 附件与正文一样，在被这条消息取走时就该离开挂起池。若等到异步编码
        // 结束再清理，编码窗口内再次触发发送会把同一批附件当成新消息再提交一次。
        if hasAttachments {
            capability.clearAttachments()
            updateAttachments()
        }

        if hasAttachments {
            Task { @MainActor in
                do {
                    guard let commit = try await capability.commitUserMessageInBackground(
                        content,
                        imageAttachments: imageAttachments,
                        fileAttachments: fileAttachments,
                        collapsedBlocks: blocks,
                        conversationID: nil
                    ) else { return }
                    Self.logger.info("\(self.t)message attachments encoded and committed")
                    guard !commit.wasQueued else { return }
                    await capability.startTurn(for: commit)
                } catch {
                    Self.logger.error("\(self.t)send failed ➡️ \(error.localizedDescription, privacy: .public)")
                    // 提交失败：附件已被消费，放回挂起池让用户直接重试。
                    imageAttachments.forEach(capability.addImageAttachment)
                    fileAttachments.forEach(capability.addFileAttachment)
                    capability.errorMessage = error.localizedDescription
                    updateAttachments()
                }
            }
            return
        }

        do {
            guard let commit = try capability.commitUserMessage(
                content,
                imageAttachments: imageAttachments,
                fileAttachments: fileAttachments,
                collapsedBlocks: blocks,
                conversationID: nil
            ) else { return }
            Self.logger.info("\(self.t)message committed successfully")
            guard !commit.wasQueued else { return }

            // 用户消息已经可见；AgentLoop 回合跟踪放到下一次 MainActor 调度。
            Task { @MainActor in
                await capability.startTurn(for: commit)
            }
        } catch {
            Self.logger.error("\(self.t)send failed ➡️ \(error.localizedDescription, privacy: .public)")
            capability.errorMessage = error.localizedDescription
        }
    }

    private static func canSend(text: String, hasAttachments: Bool) -> Bool {
        hasAttachments || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
