import Foundation
import os

/// LumiCore 的"工具服务"功能组件。
///
/// 负责 ToolService 的初始化、工具注册、启动期校验等核心功能。
/// 与 StorageComponent 类似，本组件是纯服务型（不转发 objectWillChange），
/// 持有 ToolService 实例并暴露 bootstrap 方法供 LumiCore init 调用。
@MainActor
public final class AgentToolComponent {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "agent-tool.component")

    private var toolService: ToolService?

    /// 弱持有所属的 `LumiCore`，供 `buildToolSet` 在每次发消息时取 provider
    /// 与 chatService。弱引用避免循环：LumiCore 强持有本组件（`LumiCore.swift`
    /// 的 `let agentToolComponent`），本组件不能反向强持有它。
    private weak var lumiCore: LumiCore?

    /// 服务表取不到 provider 时的降级桩：贡献空工具集与空子 Agent。
    /// 仅在 `buildToolSet` 内部使用，保证 provider 缺失时本次请求仍能返回只含内置工具的 ToolService。
    /// 用 `final class` 以满足 `AgentToolProviding: AnyObject` 的约束。
    private final class NoOpAgentToolProvider: AgentToolProviding {
        func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] { [] }
        func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] { [] }
    }

    /// 最近一次工具贡献编排（`buildToolSet`）收集到的插件失败。
    ///
    /// 反映当前启用插件集的工具加载状态——UI（「设置 → 插件」详情页）经
    /// `LumiCore.agentToolComponent` 读取，按 pluginID 匹配后展示红色 banner。
    public private(set) var toolContributionFailures: [LumiPluginContributionFailure] = []

    public init() {}

    // MARK: - Tool Service Bootstrap

    /// 初始化空壳 `ToolService` 并注入运行环境。
    ///
    /// per-request 动态注入改造后，**启动期不再收集任何工具**——工具集完全交给
    /// `buildToolSet` 在每次发消息时按当前 context 构建。本方法只做三件事：
    ///
    /// 1. 创建一个空的 `ToolService`（per-request 实例会复用它注入的 environment）。
    /// 2. 注册到 LumiCore 服务表（供旧路径 / 兜底场景按类型解析）。
    /// 3. 注入 `ToolServiceEnvironmentBridge`（verbosity / currentProjectPath）。
    ///
    /// 不再接收 `provider` / `builtInTools` 参数——它们曾用于启动期工具名校验，
    /// 现在该校验已移除（名校验改由 `buildToolSet` 的软去重承担）。
    public func bootstrapToolService(lumiCore: LumiCore) {
        self.lumiCore = lumiCore
        let toolService = ToolService()
        self.toolService = toolService

        // 注册到 LumiCore 服务表
        lumiCore.registerService(ToolService.self, toolService)
        lumiCore.registerService((any LumiToolServicing).self, toolService)

        // 注入环境，让 ToolService 能通过协议获取 verbosity / projectPath
        toolService.environment = ToolServiceEnvironmentBridge(lumiCore: lumiCore)
    }

    // MARK: - Per-request Tool Set

    /// 为一次 LLM 请求构建 per-request `ToolService`。
    ///
    /// per-request 动态注入的核心入口。每次发消息时由 `SendPipeline` 调用，按当前
    /// `context`（反映此刻世界状态：当前项目、会话、model 等）收集插件工具，合并内置
    /// 工具与子 Agent 工具，软去重后返回一份全新的 `ToolService`。本次 turn 序列全程
    /// 持有它，请求结束即释放——多个会话因此天然隔离，不会互相覆盖工具集。
    ///
    /// - Parameters:
    ///   - context: 本次请求的插件上下文（由调用方用 `makePluginContext` 构造，反映
    ///     当前项目等状态）。插件在 `agentTools(context:)` 内据此决定要不要返回工具。
    ///   - builtInTools: 内置工具（如 `ChatService.builtInTools` 的 NoOp/ConversationInfo）。
    /// - Returns: 一份就绪的 per-request `ToolService`，已装入本次合并后的工具集。
    ///   若所属 `LumiCore` 已释放（`bootstrapToolService` 未调用或内核已析构），
    ///   返回一个只含 `builtInTools` 的降级 ToolService。
    public func buildToolSet(
        context: LumiPluginContext,
        builtInTools: [any LumiAgentTool]
    ) -> ToolService {
        // 每次构建先清空失败快照（反映本次请求的最新收集状态）。
        toolContributionFailures = []

        // provider 从服务表取（LumiCore.init 时注册），让 LumiCoreKit 不必反向持有
        // App 层 PluginService。取不到时降级为空 provider——本次请求将只有内置工具。
        let provider = lumiCore?.resolveService((any AgentToolProviding).self)
            ?? NoOpAgentToolProvider()

        // 1. 收集插件工具（容错由 provider 内部逐插件 catch，见 LumiPluginRegistry+State）。
        let pluginTools = provider.agentTools(context: context)
        toolContributionFailures = provider.lastAgentToolFailures()

        // 2. 软去重合并：[plugin → builtIn]，后到者跳过并记入 failures。
        var merged: [String: any LumiAgentTool] = [:]
        var conflicts: [LumiPluginContributionFailure] = []
        func softMerge(_ tools: [any LumiAgentTool], source: String) {
            for tool in tools {
                if merged[tool.name] == nil {
                    merged[tool.name] = tool
                } else {
                    conflicts.append(LumiPluginContributionFailure(
                        pluginID: "<tool-service>",
                        pluginDisplayName: "ToolService",
                        contribution: "buildToolSet",
                        errorDescription: "工具名 '\(tool.name)' 在 \(source) 中重复，已跳过（owner: \(String(reflecting: type(of: tool)))）"
                    ))
                }
            }
        }
        softMerge(pluginTools, source: "插件工具")
        softMerge(builtInTools, source: "内置工具")

        // 3. 创建 per-request ToolService（environment 复用启动期注入的 bridge，只读共享）。
        let requestToolService = ToolService(
            tools: Array(merged.values),
            environment: toolService?.environment
        )

        // 4. 包装子 Agent：availableTools 用当前已合并的工具集快照（不含 subAgent 自身，
        //    避免子 Agent 递归委派）；executionToolService 复用本次 per-request 实例，
        //    继承路径白名单/取消机制。append 进本 ToolService。
        //    需要 lumiCore 提供 chatService——若 lumiCore 已释放则跳过子 Agent。
        let subAgentDefinitions = provider.subAgents(context: context)
        if !subAgentDefinitions.isEmpty, let chatService = lumiCore?.chatService {
            let subAgentAvailableSnapshot = requestToolService.tools
            let subAgentTools: [any LumiAgentTool] = subAgentDefinitions.map { definition in
                SubAgentDelegateTool(
                    definition: definition,
                    chatService: chatService,
                    availableTools: subAgentAvailableSnapshot,
                    executionToolService: requestToolService
                )
            }
            requestToolService.appendTools(subAgentTools)
        }

        toolContributionFailures.append(contentsOf: conflicts)
        return requestToolService
    }

    // MARK: - Accessors

    /// 获取已注册的 ToolService 实例。
    public var toolService_: ToolService? {
        toolService
    }
}
