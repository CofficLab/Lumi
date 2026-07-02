import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// CSS 语言编辑器插件：提供 CSS 补全和悬浮提示
public enum EditorCSSPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "paintpalette"

    public static let info = LumiPluginInfo(
        id: "CSSEditor",
        displayName: LumiPluginLocalization.string("CSS Language Tools", bundle: .module),
        description: LumiPluginLocalization.string("Provides CSS completions and hover help for common properties and values.", bundle: .module),
        order: 32
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorCSSPluginDescriptor.css)
        registry.registerLanguage(EditorCSSPluginDescriptor.scss)
        registry.registerLanguage(EditorCSSPluginDescriptor.sass)
        registry.registerLanguage(EditorCSSPluginDescriptor.less)
        registry.registerGrammarProvider(EditorCSSPluginGrammarProvider())

        registry.registerCompletionContributor(CSSCompletionContributor())
        registry.registerHoverContributor(CSSHoverContributor())
    }
}
