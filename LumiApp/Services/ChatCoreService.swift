import LumiChatKit
import LumiCoreKit
import LumiPluginRegistry

@MainActor
final class ChatCoreService {
    let chatService: LumiChatService
    let projectPathStore: LumiCurrentProjectPathStore
    private let toolService: ToolService

    init(
        lumiCoreService: LumiCoreService,
        pluginService: PluginService,
        toolService: ToolService,
        projectPathStore: LumiCurrentProjectPathStore
    ) {
        self.toolService = toolService
        self.projectPathStore = projectPathStore
        toolService.projectPathProvider = projectPathStore
        self.chatService = LumiChatService(
            configuration: .coreDatabase(directory: lumiCoreService.coreDatabaseDirectory)
        )
        LumiPluginBootstrap.configurePluginRuntimes(
            currentProjectPath: { [projectPathStore] in projectPathStore.currentProjectPath },
            currentProjectName: { [projectPathStore] in
                let path = projectPathStore.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !path.isEmpty else { return "" }
                return URL(fileURLWithPath: path).lastPathComponent
            },
            chatServiceProvider: { [chatService] in chatService }
        )
        chatService.registerProjectPathProvider(projectPathStore)
        reloadPluginContributions(from: pluginService)
    }

    func reloadPluginContributions(from pluginService: PluginService) {
        let context = LumiPluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiChatServicing.self, chatService)
                dependencies.register(LumiToolServicing.self, toolService)
                dependencies.register(LumiCurrentProjectPathStoring.self, projectPathStore)
            }
        )
        toolService.registerTools(pluginService.agentTools(context: context))
        chatService.registerProviders(pluginService.llmProviders(context: context))
        chatService.registerMiddlewares(pluginService.sendMiddlewares(context: context))
        chatService.registerMessageRenderers(pluginService.messageRenderers(context: context))
        chatService.registerToolService(toolService)
    }
}
