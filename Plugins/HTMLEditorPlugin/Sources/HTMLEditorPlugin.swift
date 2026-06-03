import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// HTML 编辑器插件
///
/// 提供 HTML 文件的编辑增强功能：
/// - 标签和属性补全（含 Emmet）
/// - 悬浮文档提示
/// - 标签自动闭合
/// - 标签匹配与高亮
public actor HTMLEditorPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = HTMLEditorPlugin()
    public static let id = "HTMLEditor"
    public static let displayName = String(localized: "HTML Editor", table: "HTMLEditor")
    public static let description = String(localized: "HTML editing enhancements: tag completion, hover docs, auto-closing, tag matching, and Emmet.", table: "HTMLEditor")
    public static let iconName = "curlybraces"
    public static let order = 31
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
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
