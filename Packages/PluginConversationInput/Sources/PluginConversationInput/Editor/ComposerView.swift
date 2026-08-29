import AppKit
import LumiUI
import ProviderConversationInput
import ProviderMessage
import ProviderMessageSender
import SwiftUI
import UniformTypeIdentifiers

/// 输入框组合视图
///
/// 由旧版 `ComposerView` 复刻而来；`kernel` 依赖改为注入
/// 内核的 `ConversationInputProviding` 与 `MessageSendingProviding`。
/// 图片拖拽会加入新版发送器的挂起附件池，其他文件仍以路径文本插入输入框。
struct ComposerView: View {
    @LumiTheme private var theme

    let input: (any ConversationInputProviding)?
    let sender: (any MessageSendingProviding)?

    /// 回车提交时触发的发送（与 Action Bar 发送按钮共用同一入口）
    let onSend: () -> Void

    var body: some View {
        let textBinding = Binding(
            get: { input?.text ?? "" },
            set: { input?.text = $0 }
        )
        let heightBinding = Binding(
            get: { input?.inputHeight ?? ChatInputEditorView.minHeight },
            set: { input?.inputHeight = $0 }
        )
        let focusedBinding = Binding(
            get: { input?.isInputFocused ?? false },
            set: { input?.isInputFocused = $0 }
        )
        let cursorBinding = Binding(
            get: { input?.inputCursorPosition ?? 0 },
            set: { input?.inputCursorPosition = $0 }
        )

        ChatInputEditorView(
            text: textBinding,
            height: heightBinding,
            textColor: NSColor(theme.textPrimary),
            placeholder: "输入消息，按 Return 发送…",
            onSubmit: onSend,
            onEnter: onSend,
            onFileDrop: { url in
                if ChatInputEditorRules.isChatImageFileURL(url) {
                    attachImage(url)
                } else {
                    insertDroppedFile(url)
                }
            },
            isFocused: focusedBinding,
            cursorPosition: cursorBinding,
            isImageDragHovering: .constant(false)
        )
        .frame(height: input?.inputHeight ?? ChatInputEditorView.minHeight)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .appSurface(style: .toolbar, cornerRadius: 0)
    }

    /// 拖放非图片文件：以路径文本插入输入框。
    private func insertDroppedFile(_ url: URL) {
        guard let input else { return }
        let path = url.path
        if input.text.isEmpty {
            input.text = path
        } else {
            input.text += "\n\(path)"
        }
        input.isInputFocused = true
    }

    /// 将拖入的图片加入发送器挂起池，供下一条消息携带发送。
    private func attachImage(_ url: URL) {
        guard let sender else { return }

        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
        Task { @MainActor in
            guard let data = await Task.detached(priority: .userInitiated, operation: {
                try? Data(contentsOf: url)
            }).value, !data.isEmpty else {
                return
            }

            sender.addImageAttachment(
                UserImageAttachment(
                    mimeType: mimeType,
                    base64Data: data.base64EncodedString(),
                    fileName: url.lastPathComponent
                )
            )
            input?.isInputFocused = true
        }
    }
}
