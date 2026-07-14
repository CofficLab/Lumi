import Foundation

// MARK: - Tool Service

extension LumiCore {
    // MARK: - Tool Service Bootstrap

    /// 初始化 `ToolService` 并注入运行环境。
    public func bootstrapToolService(provider: any LumiAgentToolProviding) throws {
        let toolService = ToolService()
        registerService(ToolService.self, toolService)
        registerService((any LumiToolServicing).self, toolService)
        // 注入环境，让 ToolService 能通过协议获取 verbosity / projectPath
        toolService.environment = ToolServiceEnvironmentBridge(lumiCore: self)

        // 启动期工具名校验：让 boot 阶段就能拦截插件侧的配置冲突。
        try validateToolNameUniqueness(provider: provider)
    }

    // MARK: - Tool Contributions

    /// 编排 Agent Tool 工具的注册与注入。
    ///
    /// 把 `provider` 提供的插件工具、内置工具和子 Agent 工具注册到 `ToolService`，
    /// 并把 `ToolService` 关联到 `ChatService`。App 层无需直接接触 `ToolService`、
    /// `LumiAgentTool` 或 `SubAgentDelegateTool` 任何细节。
    ///
    /// 通常在 App 层插件加载完成后调用，重复调用是安全的。
    ///
    /// 注意：工具名称唯一性校验已在 `boot()` 阶段完成，此处不再重复校验。
    ///
    /// - Parameters:
    ///   - provider: 工具/子 Agent 贡献者（通常为 `PluginService`）
    ///   - context: 当前的 `LumiPluginContext`
    public func bootstrapToolContributions(
        provider: any LumiAgentToolProviding,
        context: LumiPluginContext,
        builtInTools: [any LumiAgentTool]
    ) {
        guard let toolService = resolveService(ToolService.self) else {
            return
        }

        // 1. 收集插件工具
        let pluginTools = provider.agentTools(context: context)
        // 工具名称唯一性已在 boot 阶段通过 LumiToolNameDeduplication 校验，
        // 此处使用 registerTools 直接注册（覆盖模式）。
        // 由于 boot 已保证唯一性，理论上不会抛出错误，但 Swift 要求处理 throwing 方法。
        do {
            try toolService.registerTools(pluginTools)
        } catch {
            // 理论上不应发生（boot 已校验），但为了健壮性仍做容错处理
        }

        // 2. 注册内置工具（no_op / conversation_info）
        // 内置工具由调用方（LumiChatKit）提供，因为它们与对话业务紧密相关
        toolService.registerBuiltInTools(builtInTools)

        // 3. 收集子 Agent 定义并包装成 delegate 工具
        let subAgentDefinitions = provider.subAgents(context: context)
        if let chatService {
            let subAgentTools: [any LumiAgentTool] = subAgentDefinitions.map { definition in
                SubAgentDelegateTool(
                    definition: definition,
                    chatService: chatService,
                    toolService: toolService
                )
            }
            toolService.appendTools(subAgentTools)
        }

        // 4. 关联到 ChatService
        chatService?.registerToolService(toolService)
    }

    // MARK: - Tool Name Validation

    /// 启动期工具名校验：让 boot 阶段就能拦截插件侧的配置冲突。
    ///
    /// 构造一个最小可用的 PluginContext（chatService / toolService 已就绪），
    /// 拉取当前启用的工具列表，复用 `LumiToolNameDeduplication.validateUnique` 的
    /// 语义抛错。检测到重复时调用方应捕获并以 `CrashedView` 等方式优雅降级。
    ///
    /// - Parameter provider: 工具/子 Agent 贡献者（通常为 `PluginService`）
    /// - Throws: `LumiToolRegistrationError.duplicateNames` 当 `provider` 提供的工具名有重复。
    public func validateToolNameUniqueness(
        provider: any LumiAgentToolProviding
    ) throws {
        let bootContext = makePluginContext(
            activeSectionID: "lumi.boot",
            activeSectionTitle: "Lumi Boot"
        )
        try LumiToolNameDeduplication.validateUnique(
            tools: provider.agentTools(context: bootContext)
        )
    }
}
