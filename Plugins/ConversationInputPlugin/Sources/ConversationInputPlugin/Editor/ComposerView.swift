import AppKit
import LumiKernel
import LumiUI
import SwiftUI

struct ComposerView: View {
    @LumiTheme private var theme

    let inputState: any ConversationInputProviding

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
                // 拖入文件时把文件路径插入输入框文本（而非作为附件上传）
                let path = url.path
                if inputState.text.isEmpty {
                    inputState.text = path
                } else {
                    inputState.text += "\n\(path)"
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
}
