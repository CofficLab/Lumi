import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// Editor Chat 集成插件：提供代码发送到 AI chat 的上下文菜单操作
public enum EditorChatIntegrationPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "bubble.left"

    public static let info = LumiPluginInfo(
        id: "EditorChatIntegration",
        displayName: LumiPluginLocalization.string("Chat Integration", bundle: .module),
        description: LumiPluginLocalization.string("Adds context menu actions to send code and locations to the AI chat.", bundle: .module),
        order: 12
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCommandContributor(EditorChatIntegrationCommandContributor())
    }
}
