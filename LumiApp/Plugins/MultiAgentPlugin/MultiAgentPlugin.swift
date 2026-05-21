import Foundation
import os

/// 多智能体插件
///
/// 提供创建和收集子智能体的工具。主 Agent 可以通过 `spawn_agent` 工具
/// 创建一个或多个子智能体，每个子智能体使用指定的 LLM 供应商和模型
/// 在后台独立执行任务，然后通过 `collect_agents` 一次性收集所有结果。
///
/// ## 典型使用场景
///
/// - 让 Claude 分析代码架构，同时让 GPT-4o 翻译文档，DeepSeek 写测试
/// - 将一个大任务拆分为多个独立子任务并行执行
/// - 用不同模型对同一问题获取多角度的分析结果
///
/// ## 架构说明
///
/// - 子智能体在同一进程内通过 Swift Concurrency 并行运行
/// - 每个子智能体拥有独立的 LLM 配置和消息上下文
/// - 子智能体可以调用当前可用的工具（只读工具优先）
/// - 结果返回后子智能体上下文立即释放，不持久化
actor MultiAgentPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.multi-agent")
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose: Bool = false

    static let id: String = "MultiAgent"
    static let displayName = String(localized: "Multi Agent", table: "MultiAgent")
    static let description = String(localized: "Spawn parallel sub-agents with independent LLM providers and models", table: "MultiAgent")
    static let iconName: String = "person.3.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 88 }

    static let shared = MultiAgentPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {
        Task {
            await SubAgentRunner.shared.cancelAll()
        }
    }

    // MARK: - Agent Tools

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        guard let llmService = context.llmService,
              let llmVM = context.llmVM else {
            return []
        }
        return [
            SpawnAgentTool(llmService: llmService, llmVM: llmVM, toolService: context.toolService),
            CollectAgentsTool(),
        ]
    }
}
