import AppKit
import EditorContracts
import SwiftUI

/// 内核引用持有者（§17.2）。
///
/// 宿主在启动时注入编辑器能力；旧、新内核均可提供同一契约。
@MainActor
enum EmbeddedEditorServiceLocator {
    static var provider: (any EditorEmbeddedEditorProviding)?
}

/// 嵌入式代码/SQL 编辑器（§17.2）。
///
/// 优先使用 Host 提供的 `EditorEmbeddedEditorProviding`（真实语法高亮编辑器）；
/// Host 不可用时退回纯 SwiftUI `TextEditor`（等宽字体，只读时禁用），
/// 保证插件可独立运作。
struct EmbeddedCodeEditorView: View {
    @Binding var text: String
    var options: EditorEmbeddedEditorOptions

    init(text: Binding<String>, options: EditorEmbeddedEditorOptions) {
        self._text = text
        self.options = options
    }

    var body: some View {
        if let provider = EmbeddedEditorServiceLocator.provider {
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
