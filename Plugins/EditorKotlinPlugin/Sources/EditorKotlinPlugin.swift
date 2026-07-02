import EditorService
import LumiCoreKit
import SwiftUI
import os

public enum EditorKotlinPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-kotlin")

    public static let info = LumiPluginInfo(
        id: "kotlinHighlight",
        displayName: LumiPluginLocalization.string("Kotlin Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Syntax highlighting and language detection for Kotlin.", bundle: .module),
        order: 200
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorKotlinPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorKotlinPluginGrammarProvider())
    }
}
