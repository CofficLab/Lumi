import Combine
import Foundation
import KitSuperLog
import os
import ProviderMessage
import ProviderMessageSender
import SwiftUI
import UniformTypeIdentifiers

/// 输入框 + 附件预览唯一的数据来源与交互入口。
///
/// 输入文本、发送状态、附件列表、错误状态、输入限制全部收敛到这里；
/// 外部输入/发送事件由 `ConversationInputObserver` 写入，View 只读取状态
/// 并触发用户意图，不再直接访问任何 Provider。
@MainActor
final class ConversationInputViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-input",
        category: "ConversationInputViewModel"
    )
    nonisolated static let verbose = false

    @Published private(set) var revision = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var text = ""
    @Published private(set) var inputHeight = ChatInputEditorView.minHeight
    @Published private(set) var isInputFocused = false
    @Published private(set) var inputCursorPosition = 0
    @Published private(set) var imageAttachments: [UserImageAttachment] = []
    @Published private(set) var fileAttachments: [UserFileAttachment] = []
    @Published private(set) var canSend = false

    private let capability: any ConversationInputCapability

    init(capability: any ConversationInputCapability) {
        self.capability = capability
        refresh()
    }

    var hasAttachments: Bool {
        !imageAttachments.isEmpty || !fileAttachments.isEmpty
    }

    // MARK: - Observer 入口（外部事件 → VM）

    /// 重新从能力层生成全部界面状态。
    func refresh() {
        text = capability.text
        inputHeight = capability.inputHeight
        isInputFocused = capability.isInputFocused
        inputCursorPosition = capability.inputCursorPosition
        errorMessage = capability.errorMessage
        imageAttachments = capability.pendingImageAttachments
        fileAttachments = capability.pendingFileAttachments
        canSend = hasAttachments || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        revision &+= 1
    }

    /// 对话切换：清空输入与未提交附件。
    func handleConversationSwitched() {
        capability.clearInput()
        capability.clearAttachments()
        refresh()
    }

    // MARK: - 输入绑定（写 Provider，由 Observer 回读）

    func setText(_ value: String) {
        capability.text = value
    }

    func setInputHeight(_ value: CGFloat) {
        capability.inputHeight = value
    }

    func setFocused(_ value: Bool) {
        capability.isInputFocused = value
    }

    func setCursorPosition(_ value: Int) {
        capability.inputCursorPosition = value
    }

    // MARK: - 用户意图

    /// 发送当前输入框文本（含附件）。
    func send() {
        let trimmed = capability.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageAttachments = capability.pendingImageAttachments
        let fileAttachments = capability.pendingFileAttachments
        let hasAttachments = !imageAttachments.isEmpty || !fileAttachments.isEmpty
        guard !trimmed.isEmpty || hasAttachments else { return }

        let trace = capability.beginMetrics(
            operation: "chat.send",
            metadata: ["attachments": hasAttachments ? "true" : "false"]
        )

        capability.text = ""
        capability.errorMessage = nil
        refresh()

        if hasAttachments {
            Task { @MainActor in
                do {
                    guard let commit = try await capability.commitUserMessageInBackground(
                        trimmed,
                        imageAttachments: imageAttachments,
                        fileAttachments: fileAttachments,
                        conversationID: nil
                    ) else { return }
                    if Self.verbose {
                        Self.logger.info("attachment commit completed queued=\(commit.wasQueued)")
                    }
                    if let trace {
                        capability.markMetrics(trace, stage: "message.committed")
                        capability.endMetrics(trace)
                    }
                    guard !commit.wasQueued else { return }
                    await capability.startTurn(for: commit)
                } catch {
                    capability.errorMessage = error.localizedDescription
                    refresh()
                }
            }
            return
        }

        do {
            guard let commit = try capability.commitUserMessage(
                trimmed,
                imageAttachments: imageAttachments,
                fileAttachments: fileAttachments,
                conversationID: nil
            ) else { return }
            if let trace {
                capability.markMetrics(trace, stage: "message.committed")
                capability.endMetrics(trace)
            }
            guard !commit.wasQueued else { return }

            // 用户消息已同步进入内存时间线；回合跟踪延后，不阻塞 Return → 首帧路径。
            Task { @MainActor in
                await capability.startTurn(for: commit)
            }
        } catch {
            capability.errorMessage = error.localizedDescription
            refresh()
        }
    }

    /// 清空错误提示。
    func dismissError() {
        capability.errorMessage = nil
        refresh()
    }

    /// 将拖入目录的路径作为文本插入输入框。
    func insertDirectoryPath(_ url: URL) {
        guard !url.path.isEmpty else { return }

        let currentText = capability.text
        if currentText.isEmpty || currentText.hasSuffix("\n") {
            capability.text += url.path
        } else {
            capability.text += "\n" + url.path
        }
        capability.isInputFocused = true
        refresh()
    }

    /// 将拖入的非图片文件加入发送器挂起池。
    func attachFile(_ url: URL) {
        Task { @MainActor in
            do {
                let attachment = try await Task.detached(priority: .userInitiated) {
                    try UserFileAttachmentLoader.load(from: url)
                }.value
                capability.addFileAttachment(attachment)
                capability.isInputFocused = true
            } catch {
                capability.errorMessage = error.localizedDescription
                refresh()
            }
        }
    }

    /// 将拖入的图片加入发送器挂起池。
    func attachImage(_ url: URL) {
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
        Task { @MainActor in
            guard let attachment = await Task.detached(priority: .userInitiated, operation: { () -> UserImageAttachment? in
                guard let data = try? Data(contentsOf: url), !data.isEmpty else {
                    return nil
                }
                return UserImageAttachment(
                    mimeType: mimeType,
                    base64Data: data.base64EncodedString(),
                    fileName: url.lastPathComponent
                )
            }).value else {
                return
            }

            capability.addImageAttachment(attachment)
            capability.isInputFocused = true
        }
    }

    func removeImageAttachment(id: UUID) {
        capability.removeImageAttachment(id: id)
    }

    func removeFileAttachment(id: UUID) {
        capability.removeFileAttachment(id: id)
    }
}
