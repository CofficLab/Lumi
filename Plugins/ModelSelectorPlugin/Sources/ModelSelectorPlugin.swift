import LumiKernel
import LumiUI

@MainActor
public final class ModelSelectorPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.model-selector"
    public let name = "Model Selector"
    public let order = 82
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - Chat Action Bar

    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] {
        guard let chatService = kernel.chatSection as? any LumiChatServicing else {
            return []
        }

        return [
            ChatSectionActionBarItem(id: "\(id).action-bar-button") {
                ModelSelectorActionBarButton(chatService: chatService)
            }
        ]
    }
}
