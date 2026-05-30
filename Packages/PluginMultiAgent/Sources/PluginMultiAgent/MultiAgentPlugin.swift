import Foundation
import LumiCoreKit
import SuperLogKit
import AgentToolKit
import os
import SwiftUI
import LumiUI

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
public actor MultiAgentPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.multi-agent")
    public nonisolated static let emoji = "🤖"
    public nonisolated static let verbose: Bool = true

    public static let id: String = "MultiAgent"
    public static let displayName = String(localized: "Multi Agent", table: "MultiAgent")
    public static let description = String(localized: "Spawn parallel sub-agents with independent LLM providers and models", table: "MultiAgent")
    public static let iconName: String = "person.3.fill"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 88 }

    public static let shared = MultiAgentPlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {
        Task {
            await SubAgentRunner.shared.cancelAll()
        }
    }

    // MARK: - Agent Tools

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "多 Agent 并行",
                subtitle: "把复杂任务拆给多个子 Agent 并行执行，再统一收集结果。",
                icon: Self.iconName,
                accent: .purple,
                metrics: [
                    PluginPosterSupport.metric("Spawn", "创建"),
                    PluginPosterSupport.metric("Collect", "收集"),
                ],
                rows: ["独立模型配置", "并行子任务", "结果汇总"],
                chips: ["Agent", "并行", "工具调用"]
            ),
        ]
    }

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
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
