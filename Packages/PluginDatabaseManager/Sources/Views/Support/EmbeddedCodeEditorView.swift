import AppKit
import EditorContracts
import SwiftUI

/// 嵌入式代码/SQL 编辑器。
///
/// 优先使用 Host 提供的 `EditorEmbeddedEditorProviding`（真实语法高亮编辑器）；
/// Host 不可用时退回纯 SwiftUI `TextEditor`（等宽字体，只读时禁用），
/// 保证插件可独立运作。Provider 由 ViewModel 提供，View 不自行解析。
struct EmbeddedCodeEditorView: View {
    @Binding var text: String
    var options: EditorEmbeddedEditorOptions
    var provider: (any EditorEmbeddedEditorProviding)?

    init(text: Binding<String>, options: EditorEmbeddedEditorOptions, provider: (any EditorEmbeddedEditorProviding)? = nil) {
        self._text = text
        self.options = options
        self.provider = provider
    }

    var body: some View {
        if let provider {
            provider.makeEmbeddedEditorView(text: $text, options: options)
        } else {
            fallbackEditor
        }
    }

    /// 无 Host 编辑器时的降级实现：等宽字体纯文本编辑器。
    private var fallbackEditor: some View {
        TextEditor(text: $text)
            .font(.system(size: options.fontSize > 0 ? options.fontSize : NSFont.systemFontSize, design: .monospaced))
            .disabled(!options.isEditable)
    }
}
