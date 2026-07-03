import EditorService
import LumiCoreKit
import SwiftUI

public enum EditorAgdaPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"

    public static let info = LumiPluginInfo(
        id: "agdaHighlight",
        displayName: LumiPluginLocalization.string("Agda Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Syntax highlighting and language detection for Agda.", bundle: .module),
        order: 200
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorAgdaPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorAgdaPluginGrammarProvider())
    }
}
