import AppKit
import LumiUI
import SwiftUI
import os

private let composerInputLog = Logger(
    subsystem: "com.coffic.lumi.plugin.conversation-input",
    category: "Editor"
)

/// 输入框组合视图
///
/// 文本/高度/焦点/光标绑定与文件拖拽全部通过 `ConversationInputViewModel`
/// 表达，不再直接访问输入或发送 Provider。
struct ComposerView: View {
    @LumiTheme private var theme

    @ObservedObject private var viewModel: ConversationInputViewModel

    /// 回车提交时触发的发送（与 Action Bar 发送按钮共用同一入口）
    let onSend: () -> Void

    init(viewModel: ConversationInputViewModel, onSend: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSend = onSend
    }

    var body: some View {
        let textBinding = Binding(
            get: { viewModel.text },
            set: { viewModel.setText($0) }
        )
        let heightBinding = Binding(
            get: { viewModel.inputHeight },
            set: { viewModel.setInputHeight($0) }
        )
        let focusedBinding = Binding(
            get: { viewModel.isInputFocused },
            set: { viewModel.setFocused($0) }
        )
        let cursorBinding = Binding(
            get: { viewModel.inputCursorPosition },
            set: { viewModel.setCursorPosition($0) }
        )

        ChatInputEditorView(
            text: textBinding,
            height: heightBinding,
            textColor: NSColor(theme.textPrimary),
            placeholder: "输入消息，按 Return 发送…",
            isVerbose: true,
            log: { _ in },
            onSubmit: onSend,
            onEnter: onSend,
            onFileDrop: { url in
                if ChatInputEditorRules.isDirectoryURL(url) {
                    viewModel.insertDirectoryPath(url)
                } else if ChatInputEditorRules.isChatImageFileURL(url) {
                    viewModel.attachImage(url)
                } else {
                    viewModel.attachFile(url)
                }
            },
            isFocused: focusedBinding,
            cursorPosition: cursorBinding,
            isImageDragHovering: .constant(false)
        )
        .frame(height: viewModel.inputHeight)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .appSurface(style: .toolbar, cornerRadius: 0)
    }
}
