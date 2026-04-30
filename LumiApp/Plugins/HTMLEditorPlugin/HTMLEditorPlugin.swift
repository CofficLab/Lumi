import Foundation
import SwiftUI

/// HTML 编辑器插件
///
/// 提供 HTML 文件的编辑增强功能：
/// - 标签和属性补全
/// - 悬浮文档提示
/// - 标签自动闭合
/// - 标签匹配
actor HTMLEditorPlugin: SuperPlugin {
    static let id = "HTMLEditor"
    static let displayName = String(localized: "HTML Editor", table: "HTMLEditor")
    static let description = String(localized: "HTML editing enhancements: tag completion, hover docs, auto-closing, and tag matching.", table: "HTMLEditor")
    static let iconName = "curlybraces"
    static let order = 31
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerCompletionContributor(HTMLCompletionContributor())
        registry.registerHoverContributor(HTMLHoverContributor())
        registry.registerInteractionContributor(HTMLAutoclosingController())
    }
}
