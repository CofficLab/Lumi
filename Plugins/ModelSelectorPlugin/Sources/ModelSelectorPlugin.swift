import LumiCoreChat
import LumiKernel
import LumiUI
import os

@MainActor
public final class ModelSelectorPlugin: LumiPlugin {
    public static let verbose: Bool = true
    public nonisolated static let logger = os.Logger(subsystem: "com.coffic.lumi", category: "plugin.model-selector")

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
        guard let chatService = kernel.resolveService((any LumiChatServicing).self) else {
            return []
        }

        return [
            ChatSectionActionBarItem(id: "\(id).action-bar-button") {
                ModelSelectorActionBarButton(chatService: chatService)
            }
        ]
    }
}
