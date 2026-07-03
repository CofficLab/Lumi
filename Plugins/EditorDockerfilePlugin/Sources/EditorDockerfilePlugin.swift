import EditorService
import LumiCoreKit
import SwiftUI

public enum EditorDockerfilePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"

    public static let info = LumiPluginInfo(
        id: "dockerfileHighlight",
        displayName: LumiPluginLocalization.string("Dockerfile Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Syntax highlighting and language detection for Dockerfile.", bundle: .module),
        order: 200
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorDockerfilePluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorDockerfilePluginGrammarProvider())
    }
}
