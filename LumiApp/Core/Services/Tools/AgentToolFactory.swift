import Foundation

/// AgentTool 构建环境（在主线程构建，避免并发隔离问题）。
@MainActor
struct AgentToolEnvironment {
    let toolService: ToolService
    let llmService: LLMService?
}

/// 工具工厂协议：用于在需要依赖注入时构建工具（例如 Worker 工具需要 toolService/llmService）。
@MainActor
protocol AgentToolFactory {
    var id: String { get }
    var order: Int { get }
    func makeTools(env: AgentToolEnvironment) -> [AgentTool]
}

/// 类型擦除：便于插件返回不同具体类型的工具工厂集合。
@MainActor
struct AnyAgentToolFactory {
    let id: String
    let order: Int
    private let _make: @MainActor (AgentToolEnvironment) -> [AgentTool]

    init<F: AgentToolFactory>(_ factory: F) {
        self.id = factory.id
        self.order = factory.order
        self._make = { env in
            factory.makeTools(env: env)
        }
    }

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        _make(env)
    }
}

