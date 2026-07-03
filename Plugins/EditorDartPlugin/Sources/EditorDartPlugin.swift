import EditorService
import LumiCoreKit
import SwiftUI
import os

public enum EditorDartPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-dart")

    public static let info = LumiPluginInfo(
        id: "dartHighlight",
        displayName: LumiPluginLocalization.string("Dart Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Syntax highlighting and language detection for Dart.", bundle: .module),
        order: 200
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorDartPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorDartPluginGrammarProvider())
    }
}
