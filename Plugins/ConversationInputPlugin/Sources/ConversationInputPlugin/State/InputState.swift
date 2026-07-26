import Foundation
import SwiftUI
import EditorChatInputKit
import LumiKernel

/// 输入状态（插件内部共享）
@MainActor
final class InputState: ObservableObject {
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

    // MARK: - Sending

    /// 当前是否在向内核发送中
    func isSending(kernel: LumiKernel) -> Bool {
        kernel.messageSender?.isSending ?? false
    }

    /// 是否满足发送条件（文本非空且未在发送中）
    func canSend(kernel: LumiKernel) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending(kernel: kernel)
    }

    /// 发送当前输入框文本。
    ///
    /// 编辑器的回车提交（`onSubmit`/`onEnter`）与 Action Bar 上的发送按钮共用此入口，
    /// 保证两处行为一致。
    func send(kernel: LumiKernel) {
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
    func stop(kernel: LumiKernel) {
        kernel.messageSender?.cancelCurrentRequest()
    }
}
