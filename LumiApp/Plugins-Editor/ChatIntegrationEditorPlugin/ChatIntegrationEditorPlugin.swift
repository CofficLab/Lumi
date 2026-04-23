import Foundation

@objc(LumiChatIntegrationEditorPlugin)
@MainActor
final class ChatIntegrationEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.chat.integration"
    let displayName: String = String(localized: "Chat Integration", table: "ChatIntegrationEditor")
    override var description: String { String(localized: "Adds context menu actions to send code and locations to the AI chat.", table: "ChatIntegrationEditor") }
    let order: Int = 12

    func register(into registry: EditorExtensionRegistry) {
        registry.registerCommandContributor(ChatIntegrationCommandContributor())
    }
}
