import AppKit
import KernelLumi
import LumiUI
import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @LumiTheme private var theme

    let inputState: any ConversationInputProviding
    let kernel: KernelLumi

    /// 回车提交时触发的发送（与 Action Bar 发送按钮共用同一入口）
    let onSend: () -> Void

    var body: some View {
        ChatInputEditorView(
            text: Binding(
                get: { inputState.text },
                set: { inputState.text = $0 }
            ),
            height: Binding(
                get: { inputState.inputHeight },
                set: { inputState.inputHeight = $0 }
            ),
            textColor: NSColor(theme.textPrimary),
            onSubmit: onSend,
            onEnter: onSend,
            onFileDrop: { url in
                if ChatInputEditorRules.isChatImageFileURL(url) {
                    attachImage(url)
                } else {
                    // 非图片文件仍然把路径插入输入框文本。
                    let path = url.path
                    if inputState.text.isEmpty {
                        inputState.text = path
                    } else {
                        inputState.text += "\n\(path)"
                    }
                }
            },
            isFocused: Binding(
                get: { inputState.isInputFocused },
                set: { inputState.isInputFocused = $0 }
            ),
            cursorPosition: Binding(
                get: { inputState.inputCursorPosition },
                set: { inputState.inputCursorPosition = $0 }
            ),
            isImageDragHovering: .constant(false)
        )
        .frame(height: inputState.inputHeight)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .appSurface(style: .toolbar, cornerRadius: 0)
    }

    private func attachImage(_ url: URL) {
        guard let messageSend = kernel.messageSender else { return }

        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
        Task { @MainActor in
            guard let data = await Task.detached(priority: .userInitiated, operation: {
                try? Data(contentsOf: url)
            }).value, !data.isEmpty else { return }

            messageSend.addAttachment(
                LumiImageAttachment(
                    mimeType: mimeType,
                    base64Data: data.base64EncodedString(),
                    fileName: url.lastPathComponent
                )
            )
            inputState.isInputFocused = true
        }
    }
}
