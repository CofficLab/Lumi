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
public enum EditorHTMLPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "curlybraces"

    public static let info = LumiPluginInfo(
        id: "HTMLEditor",
        displayName: LumiPluginLocalization.string("HTML Editor", bundle: .module),
        description: LumiPluginLocalization.string("HTML editing enhancements: tag completion, hover docs, auto-closing, tag matching, and Emmet.", bundle: .module),
        order: 31
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorHTMLPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorHTMLPluginGrammarProvider())

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
