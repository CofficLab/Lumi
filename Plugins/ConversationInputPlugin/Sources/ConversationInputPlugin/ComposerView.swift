import AppKit
import EditorChatInputKit
import LumiKernel
import LumiUI
import SwiftUI

struct ComposerView: View {
    @LumiTheme private var theme

    @Binding var text: String
    @Binding var inputHeight: CGFloat
    @Binding var isInputFocused: Bool
    @Binding var inputCursorPosition: Int

    /// 回车提交时触发的发送（与 Action Bar 发送按钮共用同一入口）
    let onSend: () -> Void

    var body: some View {
        ChatInputEditorView(
            text: $text,
            height: $inputHeight,
            textColor: NSColor(theme.textPrimary),
            onSubmit: onSend,
            onEnter: onSend,
            isFocused: $isInputFocused,
            cursorPosition: $inputCursorPosition,
            isImageDragHovering: .constant(false)
        )
        .frame(height: inputHeight)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .appSurface(style: .toolbar, cornerRadius: 0)
    }
}
