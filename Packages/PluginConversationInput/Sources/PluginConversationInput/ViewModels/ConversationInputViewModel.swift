import Combine
import Foundation
import LumiLoggingKit
import os
import ProviderMessage
import ProviderConversationInputBlock
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
    /// 待插入编辑器的折叠块。生产方递交后由编辑器消费（插入 chip），
    /// 消费完成后清空，避免同一个块被重复插入。
    @Published private(set) var pendingBlock: ConversationInputBlockRequest?

    private let capability: any ConversationInputCapability

    /// 文本写入后的旁路回调，供派生的发送按钮同步状态。
    ///
    /// 发送按钮由独立的 `SendActionBarViewModel` 驱动，它只经
    /// `ActionBarInputObserver`（`addTextObserver`）获知文本变化，而该通知只覆盖
    /// 逐键输入。用这个回调把「直接写入」也通知到按钮，避免输入框有内容而按钮
    /// 停在 `disabled`。默认 nil，单测无需装配。
    var onTextWritten: ((String) -> Void)?

    init(capability: any ConversationInputCapability) {
        self.capability = capability
        refresh()
    }

    var hasAttachments: Bool {
        !imageAttachments.isEmpty || !fileAttachments.isEmpty
    }

    /// 能否发送：内容非空白，或存在待发送附件。
    ///
    /// 抽成单一判定，避免「`refresh()` 与 `setText()` 各自算一遍」后规则漂移。
    private static func canSend(text: String, hasAttachments: Bool) -> Bool {
        hasAttachments || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Observer 入口（外部事件 → VM）

    /// 重新从能力层生成全部界面状态。
    ///
    /// - Important: 只用于「可能影响整张状态表」的事件：附件变化、错误提示变化、
    ///   会话切换、附件增删。**逐键文本输入不走这里** —— 那会让每个字符重写全部
    ///   `@Published`，把整个输入框视图树拖进无谓的失效广播。文本变化走
    ///   ``updateText(_:notifyActionBar:)``。
    func refresh() {
        setTextInternal(capability.text)
        setInputHeightInternal(capability.inputHeight)
        setFocusedInternal(capability.isInputFocused)
        setCursorPositionInternal(capability.inputCursorPosition)
        setErrorMessageInternal(capability.errorMessage)
        let images = capability.pendingImageAttachments
        if images != attachmentSnapshot.imageAttachments {
            attachmentSnapshot.imageAttachments = images
            imageAttachments = images
        }
        let files = capability.pendingFileAttachments
        if files != attachmentSnapshot.fileAttachments {
            attachmentSnapshot.fileAttachments = files
            fileAttachments = files
        }
        updateCanSend()
        revision &+= 1
    }

    /// 附件快照。用于判断 `refresh()` 是否真的需要改写附件字段。
    ///
    /// `@Published` 不做等值比较，数组内容即便相同也会发 `objectWillChange`。
    /// 逐键文本变化若经过 `refresh()`，即使附件没变也会重写这两个数组，
    /// 白白触发附件预览整段重建。
    private struct AttachmentSnapshot {
        var imageAttachments: [UserImageAttachment] = []
        var fileAttachments: [UserFileAttachment] = []
    }
    private var attachmentSnapshot = AttachmentSnapshot()

    /// 接收生产方递交的折叠块，转成编辑器可消费的请求。
    ///
    /// 焦点一并打开，用户可以直接在 chip 旁边继续写指令。
    func enqueue(_ block: ConversationInputBlock) {
        pendingBlock = ConversationInputBlockRequest(
            id: block.id,
            text: block.text,
            title: block.title,
            systemImage: block.systemImage,
            collapseThreshold: block.collapseThreshold
        )
        capability.isInputFocused = true
        revision &+= 1
    }

    /// 接收编辑器上报的折叠块区间。
    ///
    /// 区间存放在能力层（草稿状态），这里只做转发。等值守卫放在写入侧，
    /// 避免逐键输入时反复改写草稿状态。
    func updateCollapsedBlocks(_ blocks: [CollapsedContentBlock]) {
        guard capability.collapsedBlocks != blocks else { return }
        capability.collapsedBlocks = blocks
    }

    /// 编辑器插入完该块后回报，避免 SwiftUI 再次带着同一个块刷新。
    func consumePendingBlock(id: UUID) {
        guard pendingBlock?.id == id else { return }
        pendingBlock = nil
    }

    /// 对话切换：清空输入与未提交附件。
    func handleConversationSwitched() {
        capability.clearInput()
        capability.clearAttachments()
        refresh()
    }

    // MARK: - 输入绑定（写 Provider，由 Observer 回读）

    /// 写入输入框文本，并**同步**重算 `canSend`。
    ///
    /// - Important: 不能只写 `capability.text` 然后等 Observer 回读。`canSend`
    ///   只在 `refresh()` 里重算，而 `refresh()` 由 `ConversationInputObserver`
    ///   驱动。任何不经过逐键文本变更通知的写入路径（粘贴、语音输入、
    ///   拖入、以及 UI 测试的一次性 `typeText`）都会让 `canSend` 停留在旧值，
    ///   表现为「输入框里有字，但发送按钮一直是灰的」。
    ///
    ///   这里同步重算是刻意的冗余：Observer 随后会再算一次，结论相同、幂等
    ///   无副作用；换来的是按钮状态不再依赖异步通知的时序。
    func setText(_ value: String) {
        capability.text = value
        // 本地同步 `text` 与 `canSend`，避免界面滞后于用户输入一拍。
        //
        // 顺序要紧：上面那行写能力层会同步触发 Provider 的 `didSet` →
        // `ConversationInputObserver` → 本方法。因此这里必须走
        // `setTextInternal` + `updateCanSend`（都不回调 onTextWritten），
        // 而不是会二次通知按钮的版本，否则一次按键会沿
        // 「编辑器 → binding → 能力层 → 观察者 → 本方法」形成回环。
        setTextInternal(value)
        updateCanSend()
        // 派生的发送按钮只经 addTextObserver 获知变化（见 onTextWritten 注释），
        // 直接写入的路径必须显式通知，否则按钮停在 disabled。
        onTextWritten?(value)
    }

    /// 文本更新的单点实现：等值守卫 + `canSend` 重算。
    ///
    /// 与 ``setText(_:)`` 的区别是**不**无条件回调 `onTextWritten`。
    ///
    /// - Parameter notifyActionBar: 能力层直写（编辑器上报）时传 true；
    ///   观察者回灌时传 false —— 那条路径能力层已经通知过按钮了。
    func updateText(_ value: String, notifyActionBar: Bool) {
        setTextInternal(value)
        updateCanSend()
        if notifyActionBar {
            onTextWritten?(value)
        }
    }

    /// 写入 `text`，值未变则不触发失效广播。
    private func setTextInternal(_ value: String) {
        guard text != value else { return }
        text = value
    }

    /// 重算 `canSend`，结果未变则不触发失效广播。
    private func updateCanSend() {
        let resolved = Self.canSend(text: text, hasAttachments: hasAttachments)
        guard canSend != resolved else { return }
        canSend = resolved
    }

    /// 写入 `inputHeight`，值未变则不触发失效广播。
    private func setInputHeightInternal(_ value: CGFloat) {
        guard inputHeight != value else { return }
        inputHeight = value
    }

    /// 写入 `isInputFocused`，值未变则不触发失效广播。
    private func setFocusedInternal(_ value: Bool) {
        guard isInputFocused != value else { return }
        isInputFocused = value
    }

    /// 写入 `inputCursorPosition`，值未变则不触发失效广播。
    private func setCursorPositionInternal(_ value: Int) {
        guard inputCursorPosition != value else { return }
        inputCursorPosition = value
    }

    /// 写入 `errorMessage`，值未变则不触发失效广播。
    private func setErrorMessageInternal(_ value: String?) {
        guard errorMessage != value else { return }
        errorMessage = value
    }

    func setInputHeight(_ value: CGFloat) {
        setInputHeightInternal(value)
        capability.inputHeight = value
    }

    func setFocused(_ value: Bool) {
        setFocusedInternal(value)
        capability.isInputFocused = value
    }

    func setCursorPosition(_ value: Int) {
        // These bindings are written by the AppKit editor while it is handling
        // an edit. Keep the ViewModel in sync before SwiftUI performs its next
        // update; otherwise updateNSView reads the old position and moves the
        // insertion point back to the left of the newly typed character.
        setCursorPositionInternal(value)
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

        // 发送瞬间的折叠块区间。草稿随后被清空，区间也必须同时作废，
        // 否则下一次发送会带上上一条消息的区间。
        let blocks = capability.collapsedBlocks

        let trace = capability.beginMetrics(
            operation: "chat.send",
            metadata: ["attachments": hasAttachments ? "true" : "false"]
        )

        capability.text = ""
        capability.errorMessage = nil
        capability.collapsedBlocks = []
        refresh()

        if hasAttachments {
            Task { @MainActor in
                do {
                    guard let commit = try await capability.commitUserMessageInBackground(
                        trimmed,
                        imageAttachments: imageAttachments,
                        fileAttachments: fileAttachments,
                        collapsedBlocks: blocks,
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
                collapsedBlocks: blocks,
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
