import Foundation
import os
import LumiLoggingKit
import ProviderMessageSender
/// Manages the state and actions for the send/stop action bar.
///
/// The plugin owns this model and its observation lifecycle. Observers update
/// `state` when the input text or sending state changes; the view only renders
/// the model and invokes its actions. All external operations go through
/// `ConversationInputCapability`.
@MainActor
final class SendActionBarViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin-conversation-input", category: "SendActionBarButton")
    nonisolated public static let emoji = "🔘"
    nonisolated static let verbose = true

    private let capability: any ConversationInputCapability
    /// 是否已经在等待在途附件读取。避免重复点击排起多条发送链。
    private var isWaitingForAttachmentReads = false

    @Published private(set) var state: SendActionBarState

    // MARK: - Lifecycle

    init(capability: any ConversationInputCapability) {
        self.capability = capability
        self.state = SendActionBarState(
            canStop: capability.canStop(for: capability.selectedConversationID),
            canSend: Self.canSend(
                text: capability.text,
                hasAttachments: !capability.pendingImageAttachments.isEmpty || !capability.pendingFileAttachments.isEmpty,
                isCommittingDraft: capability.isCommittingDraft
            )
        )
    }

    // MARK: - State updates

    func updateInputText(_ text: String) {
        state = SendActionBarState(
            canStop: state.canStop,
            canSend: Self.canSend(
                text: text,
                hasAttachments: !capability.pendingImageAttachments.isEmpty || !capability.pendingFileAttachments.isEmpty,
                isCommittingDraft: capability.isCommittingDraft
            )
        )
        // - Important: 必须把文本写回能力层。`send()` 直接读 `capability.text`
        //   而不是 `state` 里的副本；若这里只更新 `canSend` 判定，调用方
        //   （直接写入路径，如粘贴、UI 测试的 typeText）点发送时会因为
        //   `capability.text` 仍为空而静默 return——按钮亮着、点了没反应。
        capability.text = text
    }

    func updateAttachments() {
        refreshSendState()
    }

    /// 重算发送按钮状态。正文、附件、提交中标记任一变化都要走这里，
    /// 否则按钮会停在旧结论上（例如提交中仍然亮着）。
    private func refreshSendState() {
        state = SendActionBarState(
            canStop: state.canStop,
            canSend: Self.canSend(
                text: capability.text,
                hasAttachments: !capability.pendingImageAttachments.isEmpty || !capability.pendingFileAttachments.isEmpty,
                isCommittingDraft: capability.isCommittingDraft
            )
        )
    }

    func refreshConversationState() {
        guard let conversationID = capability.selectedConversationID else {
            state = SendActionBarState(canStop: false, canSend: state.canSend)
            return
        }
        state = SendActionBarState(
            canStop: capability.canStop(for: conversationID),
            canSend: state.canSend
        )
    }

    // MARK: - Actions

    /// Cancel the current in-flight request.
    func cancel() {
        capability.cancelCurrentRequest()
        Self.logger.info("\(self.t)cancelled current request")
    }

    /// Send the current input text. Clears the input field on success.
    func send() {
        // 提交中的草稿还在输入框里，此时再次触发会把同一条正文（或同一批
        // 附件）当成新消息重复提交。标记由两条发送入口共用。
        guard !capability.isCommittingDraft else { return }

        // 附件还在异步读取：等读取结束再快照，否则这条消息会漏掉用户刚选中
        // 的附件，附件又滚进下一条无关消息（#1023）。
        if capability.pendingAttachmentReadCount > 0 {
            guard !isWaitingForAttachmentReads else { return }
            isWaitingForAttachmentReads = true
            Task { @MainActor in
                await capability.waitForAttachmentReads()
                isWaitingForAttachmentReads = false
                send()
            }
            return
        }

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
        // 发送瞬间的折叠块区间。提交成功后草稿被清空，区间也必须同时作废，
        // 否则下一次发送会带上上一条消息的区间。
        let blocks = capability.collapsedBlocks
        capability.errorMessage = nil

        if hasAttachments {
            // 附件必须在发送瞬间离开挂起池。若等到异步编码结束再清理，
            // 编码窗口内再次触发发送会把同一批附件当成新消息再提交一次。
            capability.clearAttachments()
            capability.isCommittingDraft = true
            refreshSendState()

            Task { @MainActor in
                let commit: MessageSendCommit?
                do {
                    commit = try await capability.commitUserMessageInBackground(
                        content,
                        imageAttachments: imageAttachments,
                        fileAttachments: fileAttachments,
                        collapsedBlocks: blocks,
                        conversationID: nil
                    )
                } catch {
                    Self.logger.error("\(self.t)send failed ➡️ \(error.localizedDescription, privacy: .public)")
                    // 提交失败：附件已被消费，放回挂起池；正文与折叠块从未
                    // 清空，仍在输入框里，用户修正故障后可直接重试。
                    imageAttachments.forEach(capability.addImageAttachment)
                    fileAttachments.forEach(capability.addFileAttachment)
                    capability.errorMessage = error.localizedDescription
                    capability.isCommittingDraft = false
                    refreshSendState()
                    return
                }

                // 提交结束即释放门禁；后面的回合跟踪不能继续挡住发送。
                capability.isCommittingDraft = false

                guard let commit else {
                    // 未形成有效提交：保留草稿，附件放回挂起池。
                    imageAttachments.forEach(capability.addImageAttachment)
                    fileAttachments.forEach(capability.addFileAttachment)
                    refreshSendState()
                    return
                }

                clearSentDraft(content: content)
                refreshSendState()
                Self.logger.info("\(self.t)message attachments encoded and committed")
                guard !commit.wasQueued else { return }
                await capability.startTurn(for: commit)
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
            ) else {
                // 未形成有效提交：草稿原样保留，只刷新按钮状态。
                refreshSendState()
                return
            }

            clearSentDraft(content: content)
            refreshSendState()
            Self.logger.info("\(self.t)message committed successfully")
            guard !commit.wasQueued else { return }

            // 用户消息已经可见；AgentLoop 回合跟踪放到下一次 MainActor 调度。
            Task { @MainActor in
                await capability.startTurn(for: commit)
            }
        } catch {
            Self.logger.error("\(self.t)send failed ➡️ \(error.localizedDescription, privacy: .public)")
            // 提交失败：草稿（正文 + 折叠块）原样保留。
            capability.errorMessage = error.localizedDescription
            refreshSendState()
        }
    }

    /// 提交成功后清空本次发送的草稿。
    ///
    /// - Important: 只清空**本次发送的那一份**草稿。附件编码期间用户可能继续
    ///   输入，此时输入框已经不是发出去的内容，直接清空会吞掉新草稿。
    private func clearSentDraft(content: String) {
        guard capability.text == content else { return }
        capability.text = ""
        capability.collapsedBlocks = []
    }

    private static func canSend(text: String, hasAttachments: Bool, isCommittingDraft: Bool) -> Bool {
        guard !isCommittingDraft else { return false }
        return hasAttachments || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
