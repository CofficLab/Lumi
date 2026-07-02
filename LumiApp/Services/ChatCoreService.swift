import Foundation
import LumiChatKit
import LumiCoreKit
import LumiPluginRegistry
import SuperLogKit
import os

@MainActor
final class ChatCoreService: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.chat-core")
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = true

    let chatService: ChatService
    private let toolService: ToolService

    init(
        lumiCoreService: LumiCoreService,
        pluginService: PluginService,
        toolService: ToolService
    ) {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 ChatCoreService")
        }

        self.toolService = toolService
        self.chatService = ChatService(
            configuration: .coreDatabase(directory: lumiCoreService.coreDatabaseDirectory)
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ ChatService 初始化完成")
        }

        // 触发插件生命周期 - 项目打开
        let projectPath = LumiCore.projectState?.currentProject?.path ?? ""
        if !projectPath.isEmpty {
            Task {
                await LumiPluginRegistry.projectDidOpen(path: projectPath)
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 插件运行时配置完成")
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)重载插件贡献")
        }
        reloadPluginContributions(from: pluginService)

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ ChatCoreService 初始化完成")
        }
    }

    func reloadPluginContributions(from pluginService: PluginService) {
        if Self.verbose {
            Self.logger.info("\(Self.t)重载插件贡献")
        }

        let context = LumiPluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register((any LumiChatServicing).self, chatService)
                dependencies.register((any HistoryQueryService).self, chatService)
                dependencies.register(LumiToolServicing.self, toolService)
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

        NotificationCenter.default.post(
            name: .lumiLLMProvidersDidChange,
            object: nil,
            userInfo: nil
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 插件贡献重载完成: \(providers.count) 个 LLM Provider")
        }
    }
}
