import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class ModelSelectorPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.model-selector"
    public let name = "Model Selector"
    public let order = 82
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onReady(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - Chat Action Bar

    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] {
        guard let llmProvider = kernel.llmProvider else {
            return []
        }

        return [
            ChatSectionActionBarItem(id: "\(id).action-bar-button") {
                ModelSelectorActionBarButton(
                    llmProvider: llmProvider,
                    conversationManaging: kernel.conversations
                )
            }
        ]
    }
}
