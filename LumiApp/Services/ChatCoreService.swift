import LumiChatKit
import LumiCoreKit

@MainActor
final class ChatCoreService {
    let chatService: LumiChatService
    private let toolService: ToolService

    init(lumiCoreService: LumiCoreService, pluginService: PluginService, toolService: ToolService) {
        self.toolService = toolService
        self.chatService = LumiChatService(
            configuration: .coreDatabase(directory: lumiCoreService.coreDatabaseDirectory)
        )
        reloadPluginContributions(from: pluginService)
    }

    func reloadPluginContributions(from pluginService: PluginService) {
        let context = LumiPluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiChatServicing.self, chatService)
                dependencies.register(LumiToolServicing.self, toolService)
            }
        )
        toolService.registerTools(pluginService.agentTools(context: context))
        chatService.registerProviders(pluginService.llmProviders(context: context))
        chatService.registerMiddlewares(pluginService.sendMiddlewares(context: context))
        chatService.registerMessageRenderers(pluginService.messageRenderers(context: context))
        chatService.registerToolService(toolService)
    }
}
