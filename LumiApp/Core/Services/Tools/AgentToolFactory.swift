import Foundation

/// SuperAgentTool 构建环境（在主线程构建，避免并发隔离问题）。
@MainActor
struct SuperAgentToolEnvironment {
    let toolService: ToolService
    let llmService: LLMService?
}

/// 类型擦除：便于插件返回不同具体类型的工具工厂集合。
@MainActor
struct AnySuperAgentToolFactory {
    let id: String
    let order: Int
    private let _make: @MainActor (SuperAgentToolEnvironment) -> [SuperAgentTool]

    init<F: SuperAgentToolFactory>(_ factory: F) {
        self.id = factory.id
        self.order = factory.order
        self._make = { env in
            factory.makeTools(env: env)
        }
    }

    func makeTools(env: SuperAgentToolEnvironment) -> [SuperAgentTool] {
        _make(env)
    }
}
