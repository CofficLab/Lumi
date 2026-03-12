import Foundation
import MagicKit

/// Worker 相关工具插件
///
/// 提供 Worker 类型描述符与相关工具（例如 CreateAndAssignTaskTool）。
actor AgentWorkerToolsPlugin: SuperPlugin {
    static let id: String = "AgentWorkerTools"
    static let displayName: String = "Worker Tools"
    static let description: String = "提供 Worker 类型描述符与 Worker 协作相关的 Agent 工具。"
    static let iconName: String = "person.3.sequence"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 10 }

    static let shared = AgentWorkerToolsPlugin()

    // MARK: - Agent Tools

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(WorkerToolsFactory())]
    }

    // MARK: - Worker Descriptors

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

    @MainActor
    func toolPresentationDescriptors() -> [ToolPresentationDescriptor] {
        [
            .init(
                toolName: CreateAndAssignTaskTool.toolName,
                displayName: "智能助手",
                emoji: "🧩",
                category: .agent,
                order: 0
            )
        ]
    }
}

@MainActor
private struct WorkerToolsFactory: AgentToolFactory {
    let id: String = "worker.tools.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        guard let llm = env.llmService else {
            return []
        }

        let workerManager = WorkerAgentManager(llmService: llm)
        return [
            CreateAndAssignTaskTool(
                workerAgentManager: workerManager,
                toolService: env.toolService
            )
        ]
    }
}

