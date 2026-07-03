import EditorService
import LumiCoreKit
import SwiftUI
import os

public enum EditorYAMLPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-yaml")

    public static let info = LumiPluginInfo(
        id: "yamlHighlight",
        displayName: LumiPluginLocalization.string("YAML Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Syntax highlighting and language detection for YAML.", bundle: .module),
        order: 200
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorYAMLPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorYAMLPluginGrammarProvider())
    }
}
