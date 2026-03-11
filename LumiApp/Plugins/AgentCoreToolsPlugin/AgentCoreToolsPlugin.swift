import Foundation
import MagicKit

/// Agent Core Tools 插件
///
/// 将核心工具集从内核硬编码迁移到插件系统，便于增删与组合。
/// 该插件不可配置且默认启用，确保基础工具始终可用。
actor AgentCoreToolsPlugin: SuperPlugin {
    static let id: String = "AgentCoreTools"
    static let displayName: String = "Agent Core Tools"
    static let description: String = "提供 Lumi 的基础 Agent 工具（文件/命令/worker）。"
    static let iconName: String = "wrench.and.screwdriver"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 0 }

    static let shared = AgentCoreToolsPlugin()

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(CoreToolsFactory())]
    }

    @MainActor
    func workerAgentDescriptors() -> [WorkerAgentDescriptor] {
        [
            .init(
                id: "code_expert",
                displayName: "代码专家",
                roleDescription: "专注代码分析、修改、重构与优化。",
                specialty: "代码问题定位、重构、性能优化",
                systemPrompt: """
                You are a code expert worker.
                Focus on code analysis, bug finding, refactoring and implementation quality.
                Keep outputs practical and directly actionable.
                """,
                order: 0
            ),
            .init(
                id: "document_expert",
                displayName: "文档专家",
                roleDescription: "专注技术文档、接口说明与注释整理。",
                specialty: "文档结构化表达、API 说明",
                systemPrompt: """
                You are a documentation expert worker.
                Focus on writing clear, structured technical documentation and concise explanations.
                """,
                order: 10
            ),
            .init(
                id: "test_expert",
                displayName: "测试专家",
                roleDescription: "专注单元测试、集成测试与质量检查。",
                specialty: "测试用例设计、边界场景覆盖",
                systemPrompt: """
                You are a test expert worker.
                Focus on test strategy, test cases, edge conditions, and quality validation.
                """,
                order: 20
            ),
            .init(
                id: "architect",
                displayName: "架构师",
                roleDescription: "专注系统设计、代码审查与架构优化。",
                specialty: "架构权衡、模块边界、技术选型",
                systemPrompt: """
                You are an architecture expert worker.
                Focus on system design tradeoffs, scalability, maintainability, and risk analysis.
                """,
                order: 30
            ),
        ]
    }
}

@MainActor
private struct CoreToolsFactory: AgentToolFactory {
    let id: String = "core.tools.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        var tools: [AgentTool] = [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            ShellTool(),
        ]

        if let llm = env.llmService {
            let workerManager = WorkerAgentManager(llmService: llm)
            tools.append(CreateAndAssignTaskTool(workerAgentManager: workerManager, toolService: env.toolService))
        }

        return tools
    }
}

