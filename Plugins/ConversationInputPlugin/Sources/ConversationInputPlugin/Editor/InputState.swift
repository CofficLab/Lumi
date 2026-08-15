import Foundation
import SwiftUI
import KernelLumi

/// 输入状态（插件内部共享）
@MainActor
final class InputState: ObservableObject, ConversationInputProviding {
    /// 当前输入框的文本
    @Published var text: String = ""

    /// 输入框高度（64-300自适应）
    @Published var inputHeight: CGFloat = ChatInputEditorView.minHeight

    /// 输入框是否获得焦点
    @Published var isInputFocused: Bool = false

    /// 光标位置
    @Published var inputCursorPosition: Int = 0

    /// 最近一次发送失败时的错误信息（nil 表示无错误）
    @Published var errorMessage: String?

    init() {}

    func addToConversation(fileURLs: [URL], windowId: UUID?) {
        let paths = fileURLs
            .map { $0.standardizedFileURL.path }
            .filter { !$0.isEmpty }
        guard !paths.isEmpty else { return }

        let referenceBlock = Self.makeReferenceBlock(from: paths)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = referenceBlock
        } else {
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            text += "\n\n"
            text += referenceBlock
        }
        isInputFocused = true
    }

    // MARK: - Sending

    /// 当前是否在向内核发送中
    func isSending(kernel: KernelLumi) -> Bool {
        kernel.messageSender?.isSending(for: kernel.conversations?.selectedConversationID) ?? false
    }

    /// 是否满足发送条件。发送中仍允许提交，消息会进入当前对话的待发送队列。
    func canSend(kernel: KernelLumi) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 发送当前输入框文本。
    ///
    /// 编辑器的回车提交（`onSubmit`/`onEnter`）与 Action Bar 上的发送按钮共用此入口，
    /// 保证两处行为一致。
    func send(kernel: KernelLumi) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let messageSend = kernel.messageSender else {
            errorMessage = "Message service is not available"
            return
        }

        text = ""
        errorMessage = nil

        Task { @MainActor in
            do {
                try await messageSend.sendMessage(trimmed, conversationID: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 取消当前发送请求。
    func stop(kernel: KernelLumi) {
        kernel.messageSender?.cancelCurrentRequest()
    }

    /// 把文件路径列表拼接成可直接写入输入框的多行字符串。
    ///
    /// 需求变更:右键"添加到对话"时不再附加任何标题/前缀,直接以
    /// 「一行一个绝对路径」的原始形式落到输入框,便于用户继续编辑与发送。
    private static func makeReferenceBlock(from paths: [String]) -> String {
        paths.joined(separator: "\n")
    }
}
