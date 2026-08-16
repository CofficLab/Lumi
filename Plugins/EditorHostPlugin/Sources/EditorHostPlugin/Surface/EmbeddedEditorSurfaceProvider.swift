import AppKit
import EditorLanguageRuntime
import EditorService
import EditorSource
import KernelLumi
import LumiUI
import SwiftUI

/// 嵌入式编辑器能力的 Host 实现（重构方案 §17.2）。
///
/// 用与编辑器主 Surface 相同的语言/语法高亮栈（`SourceEditor` +
/// `LanguageRegistry` + 语法主题）组装小型嵌入式编辑器，
/// 供 Feature 插件（如 DatabaseManagerPlugin 的 SQL/DDL 编辑区）使用，
/// 使其无需依赖 `EditorService` / `EditorSource`。
@MainActor
final class EmbeddedEditorSurfaceProvider: EditorEmbeddedEditorProviding {

    private let service: EditorService

    init(service: EditorService) {
        self.service = service
    }

    func makeEmbeddedEditorView(text: Binding<String>, options: EditorEmbeddedEditorOptions) -> AnyView {
        AnyView(
            EmbeddedEditorHostView(
                text: text,
                options: options,
                language: resolveLanguage(for: options.languageID)
            )
        )
    }

    /// 由语言注册表解析语言上下文；未注册语言退回纯文本。
    private func resolveLanguage(for languageID: String) -> EditorLanguageContext {
        service.editorExtensions.languageRegistry.context(for: languageID)
            ?? EditorLanguageContext.plainText
    }
}

/// 持有每个嵌入位独立 `SourceEditorState` 的包装视图。
private struct EmbeddedEditorHostView: View {
    @Binding var text: String
    let options: EditorEmbeddedEditorOptions
    let language: EditorLanguageContext

    @State private var editorState = SourceEditorState()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SourceEditor(
            $text,
            language: language,
            configuration: configuration,
            state: $editorState
        )
    }

    private var configuration: SourceEditorConfiguration {
        let resolved = LumiUIThemeRegistry.shared.resolvedEditorSyntax(colorScheme: colorScheme)
        let palette = resolved?.palette ?? .standard(isDark: colorScheme == .dark)
        let fontSize = options.fontSize > 0 ? options.fontSize : NSFont.systemFontSize
        return SourceEditorConfiguration(
            appearance: .init(
                theme: EditorSyntaxPaletteAdapter.makeEditorTheme(from: palette),
                themeIdentifier: resolved?.themeId ?? "embedded-\(options.languageID)-\(colorScheme == .dark ? "dark" : "light")",
                useThemeBackground: options.useThemeBackground,
                font: .monospacedSystemFont(ofSize: fontSize, weight: .regular),
                wrapLines: options.wrapLines,
                tabWidth: 4
            ),
            behavior: .init(isEditable: options.isEditable, isSelectable: options.isSelectable),
            layout: .init(
                additionalTextInsets: NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            ),
            peripherals: .init(
                showGutter: options.showGutter,
                showMinimap: false,
                showReformattingGuide: false,
                showFoldingRibbon: false
            )
        )
    }
}
