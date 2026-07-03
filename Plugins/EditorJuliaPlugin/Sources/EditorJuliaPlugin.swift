import EditorService
import LumiCoreKit
import SwiftUI
import os

public enum EditorJuliaPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-julia")

    public static let info = LumiPluginInfo(
        id: "juliaHighlight",
        displayName: LumiPluginLocalization.string("Julia Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Syntax highlighting and language detection for Julia.", bundle: .module),
        order: 200
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorJuliaPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorJuliaPluginGrammarProvider())
    }
}
