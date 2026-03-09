import Foundation
import MagicKit
import OSLog

/// Worker 生命周期管理器
///
/// 负责 Worker 的创建、执行、状态跟踪和销毁。
actor WorkerAgentManager: SuperLog {
    nonisolated static let emoji = "🧑‍💼"
    nonisolated static let verbose = true

    private let llmService: any WorkerLLMServiceProtocol
    private var workerStatuses: [UUID: WorkerStatus] = [:]

    init(llmService: any WorkerLLMServiceProtocol) {
        self.llmService = llmService
    }

    func executeTask(
        type: WorkerAgentType,
        task: String,
        config: LLMConfig,
        toolService: any WorkerToolServiceProtocol
    ) async throws -> String {
        var worker = makeWorker(type: type, config: config)
        var workerTask = WorkerTask(description: task)
        workerTask.assignedTo = worker.id
        workerTask.status = .running
        worker.currentTask = workerTask
        worker.status = .working(taskId: workerTask.id)
        workerStatuses[worker.id] = worker.status

        if Self.verbose {
            os_log("\(Self.t)🚀 创建 Worker: \(worker.name), type=\(type.rawValue)")
        }

        do {
            let service = WorkerAgentService(llmService: llmService, toolService: toolService)
            let result = try await service.execute(worker: worker, task: task)

            workerTask.status = .completed
            workerTask.result = result
            workerTask.completedAt = Date()
            worker.status = .idle
            worker.lastActiveAt = Date()
            workerStatuses[worker.id] = worker.status
            workerStatuses.removeValue(forKey: worker.id)

            return result
        } catch {
            worker.status = .error(message: error.localizedDescription)
            workerStatuses[worker.id] = worker.status
            workerStatuses.removeValue(forKey: worker.id)
            throw error
        }
    }

    func getWorkerStatus(id: UUID) -> WorkerStatus? {
        workerStatuses[id]
    }

    private func makeWorker(type: WorkerAgentType, config: LLMConfig) -> WorkerAgent {
        WorkerAgent(
            name: displayName(for: type),
            type: type,
            description: roleDescription(for: type),
            specialty: specialty(for: type),
            config: config,
            systemPrompt: systemPrompt(for: type)
        )
    }

    private func displayName(for type: WorkerAgentType) -> String {
        switch type {
        case .codeExpert: return "代码专家"
        case .documentExpert: return "文档专家"
        case .testExpert: return "测试专家"
        case .architect: return "架构师"
        }
    }

    private func roleDescription(for type: WorkerAgentType) -> String {
        switch type {
        case .codeExpert:
            return "专注代码分析、修改、重构与优化。"
        case .documentExpert:
            return "专注技术文档、接口说明与注释整理。"
        case .testExpert:
            return "专注单元测试、集成测试与质量检查。"
        case .architect:
            return "专注系统设计、代码审查与架构优化。"
        }
    }

    private func specialty(for type: WorkerAgentType) -> String {
        switch type {
        case .codeExpert:
            return "代码问题定位、重构、性能优化"
        case .documentExpert:
            return "文档结构化表达、API 说明"
        case .testExpert:
            return "测试用例设计、边界场景覆盖"
        case .architect:
            return "架构权衡、模块边界、技术选型"
        }
    }

    private func systemPrompt(for type: WorkerAgentType) -> String {
        switch type {
        case .codeExpert:
            return """
            You are a code expert worker.
            Focus on code analysis, bug finding, refactoring and implementation quality.
            Keep outputs practical and directly actionable.
            """
        case .documentExpert:
            return """
            You are a documentation expert worker.
            Focus on writing clear, structured technical documentation and concise explanations.
            """
        case .testExpert:
            return """
            You are a test expert worker.
            Focus on test strategy, test cases, edge conditions, and quality validation.
            """
        case .architect:
            return """
            You are an architecture expert worker.
            Focus on system design tradeoffs, scalability, maintainability, and risk analysis.
            """
        }
    }
}
