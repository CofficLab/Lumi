import LumiChatKit
import Foundation
import LumiCoreKit
import LumiPluginRegistry
import ProjectsPlugin

@MainActor
final class ChatCoreService {
    let chatService: ChatService
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
        self.chatService = ChatService(
            configuration: .coreDatabase(directory: lumiCoreService.coreDatabaseDirectory)
        )
        LumiPluginBootstrap.configurePluginRuntimes(
            currentProjectPath: { [projectPathStore] in projectPathStore.currentProjectPath },
            currentProjectName: { [projectPathStore] in
                let path = projectPathStore.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !path.isEmpty else { return "" }
                return URL(fileURLWithPath: path).lastPathComponent
            },
            chatServiceProvider: { [chatService] in chatService },
            askUserResumer: chatService
        )
        chatService.registerProjectPathProvider(projectPathStore)
        reloadPluginContributions(from: pluginService)
    }

    func reloadPluginContributions(from pluginService: PluginService) {
        let context = LumiPluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register((any LumiChatServicing).self, chatService)
                dependencies.register((any HistoryQueryService).self, chatService)
                dependencies.register(LumiToolServicing.self, toolService)
                dependencies.register(LumiCurrentProjectPathStoring.self, projectPathStore)
                dependencies.register(LumiProjectStoring.self, ProjectsPlugin.sharedStore)
            }
        )

        // 注册插件提供的工具
        toolService.registerTools(pluginService.agentTools(context: context))
        // 注册 built-in tools（如 conversation_info, no_op）
        toolService.registerBuiltInTools(ChatService.builtInTools)

        let providers = pluginService.llmProviders(context: context)
        chatService.registerProviders(providers)
        chatService.registerMiddlewares(pluginService.sendMiddlewares(context: context))
        chatService.registerMessageRenderers(pluginService.messageRenderers(context: context))
        chatService.registerToolService(toolService)

        // 初始化 LLM 可用性检测
        LumiPluginBootstrap.configureAvailabilityChecker(providers: providers)
    }
}
