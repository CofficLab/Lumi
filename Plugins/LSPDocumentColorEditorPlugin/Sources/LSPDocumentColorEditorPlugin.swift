import Foundation
import EditorService
import LumiCoreKit
/// LSP 文档颜色编辑器插件。
///
/// 该插件对应 LSP 的 `textDocument/documentColor` 和 `textDocument/colorPresentation` 能力，
/// 用于识别文档中的颜色字面量，并在编辑器中以色块形式展示或提供颜色文本表示。
///
/// 当前主入口不直接注册 Provider；文档颜色能力由同目录下的 `DocumentColorProvider` 实现，
/// 展示组件位于 `Views/ColorPreview.swift`。该结构保留为独立插件边界，方便后续接入
/// 编辑器 Overlay、Gutter 或弹窗能力。
///
/// 完整启用该能力需要 LSP 服务可用，且当前语言服务器支持 document color 相关 LSP 方法。
public actor LSPDocumentColorEditorPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = LSPDocumentColorEditorPlugin()
    public static let id = "LSPDocumentColorEditor"
    public static let displayName = String(localized: "LSP Document Colors", table: "LSPDocumentColorEditor")
    public static let description = String(localized: "Displays color swatches for color literals from the language server.", table: "LSPDocumentColorEditor")
    public static let iconName = "paintpalette"
    public static let order = 28
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        // Provided via DocumentColorProvider
    }
}
