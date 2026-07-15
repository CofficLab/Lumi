import Foundation

// MARK: - Tool Service

extension LumiCore {
    // MARK: - Tool Service Bootstrap

    /// 初始化 `ToolService` 并注入运行环境。
    ///
    /// `builtInTools` 是 LumiCore 之外、运行期一定会注入 `ToolService` 的内置工具
    /// （例如 `ChatService.builtInTools`）。把它们也纳入启动期校验，确保 boot 阶段
    /// 就能拦截"plugin 工具 ↔ 内置工具"、"内置工具 ↔ sub-agent delegate 工具"等
    /// 跨来源的命名冲突，而不是等到聊天发消息时再被 `assertUnique` 拦下。
    public func bootstrapToolService(
        provider: any LumiAgentToolProviding,
        builtInTools: [any LumiAgentTool] = []
    ) throws {
        let toolService = ToolService()
        registerService(ToolService.self, toolService)
        registerService((any LumiToolServicing).self, toolService)
        // 注入环境，让 ToolService 能通过协议获取 verbosity / projectPath
        toolService.environment = ToolServiceEnvironmentBridge(lumiCore: self)

        // 启动期工具名校验：让 boot 阶段就能拦截插件侧的配置冲突。
        try validateToolNameUniqueness(provider: provider, builtInTools: builtInTools)
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
    /// 校验的是 `ToolService` 在 bootstrap 结束后**最终**累积的工具集：
    /// plugin 工具 + 内置工具 + sub-agent delegate 工具。这三者共同决定了
    /// 聊天时 `LumiLLMRequest.tools` 的内容，必须提前到 boot 阶段一并校验。
    ///
    /// - Parameters:
    ///   - provider: 工具/子 Agent 贡献者（通常为 `PluginService`）
    ///   - builtInTools: 运行期会由 `registerBuiltInTools(_:)` 注入的内置工具
    ///     （例如 `ChatService.builtInTools`）。不在 `provider` 提供的范围内。
    /// - Throws: `LumiToolRegistrationError.duplicateNames` 当合并后的工具名有重复。
    public func validateToolNameUniqueness(
        provider: any LumiAgentToolProviding,
        builtInTools: [any LumiAgentTool] = []
    ) throws {
        let bootContext = makePluginContext(
            activeSectionID: "lumi.boot",
            activeSectionTitle: "Lumi Boot"
        )

        // 1. plugin 工具：来源是 `provider.agentTools(context:)`，owner 是真实类型
        let pluginEntries = provider.agentTools(context: bootContext).map { tool in
            LumiToolNameDeduplication.ValidateEntry(
                name: tool.name,
                owner: String(reflecting: type(of: tool))
            )
        }

        // 2. 内置工具：来源是 `builtInTools` 参数，owner 加 `<built-in>.` 前缀以区分
        let builtInEntries = builtInTools.map { tool in
            LumiToolNameDeduplication.ValidateEntry(
                name: tool.name,
                owner: "<built-in>.\(String(reflecting: type(of: tool)))"
            )
        }

        // 3. sub-agent delegate 工具：name = "delegate_<definition.id>"，来源与 plugin 工具平级
        //    这里直接根据定义拼装名称，无需构造完整的 `SubAgentDelegateTool` 实例
        //    （实例化需要 chatService / toolService，会污染 boot 阶段的依赖图）
        let subAgentEntries = provider.subAgents(context: bootContext).map { definition in
            LumiToolNameDeduplication.ValidateEntry(
                name: "delegate_\(definition.id)",
                owner: "SubAgentDelegateTool[\(definition.id)]"
            )
        }

        try LumiToolNameDeduplication.validateUnique(
            entries: pluginEntries + builtInEntries + subAgentEntries
        )
    }
}
