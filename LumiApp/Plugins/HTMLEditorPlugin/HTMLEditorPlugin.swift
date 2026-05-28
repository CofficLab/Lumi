import Foundation
import SwiftUI

/// HTML 编辑器插件
///
/// 提供 HTML 文件的编辑增强功能：
/// - 标签和属性补全（含 Emmet）
/// - 悬浮文档提示
/// - 标签自动闭合
/// - 标签匹配与高亮
actor HTMLEditorPlugin: SuperPlugin {
    static let shared = HTMLEditorPlugin()
    static let id = "HTMLEditor"
    static let displayName = String(localized: "HTML Editor", table: "HTMLEditor")
    static let description = String(localized: "HTML editing enhancements: tag completion, hover docs, auto-closing, tag matching, and Emmet.", table: "HTMLEditor")
    static let iconName = "curlybraces"
    static let order = 31
    static var category: PluginCategory { .editor }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // Phase 1: 基础编辑
        registry.registerCompletionContributor(HTMLCompletionContributor())
        registry.registerHoverContributor(HTMLHoverContributor())
        registry.registerInteractionContributor(HTMLAutoclosingController())

        // Phase 1.2: Emmet 补全（通过 completion contributor 注册）
        registry.registerCompletionContributor(HTMLEmmetContributor())

        // Phase 2: 结构化编辑 - 标签高亮装饰
        registry.registerGutterDecorationContributor(TagHighlighter())
    }
}
