import Foundation

/// 工具工厂协议：用于在需要依赖注入时构建工具（例如 Worker 工具需要 toolService/llmService）。
@MainActor
protocol SuperAgentToolFactory {
    var id: String { get }
    var order: Int { get }
    func makeTools(env: SuperSuperAgentToolEnvironment) -> [SuperAgentTool]
}
