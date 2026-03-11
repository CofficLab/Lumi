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
        typeId: String,
        task: String,
        config: LLMConfig,
        toolService: any WorkerToolServiceProtocol
    ) async throws -> String {
        guard let descriptor = await resolveDescriptor(typeId: typeId) else {
            throw NSError(
                domain: "WorkerAgentManager",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Unknown workerType: \(typeId)"]
            )
        }

        var worker = makeWorker(descriptor: descriptor, config: config)
        var workerTask = WorkerTask(description: task)
        workerTask.assignedTo = worker.id
        workerTask.status = .running
        worker.currentTask = workerTask
        worker.status = .working(taskId: workerTask.id)
        workerStatuses[worker.id] = worker.status

        if Self.verbose {
            os_log("\(Self.t)🚀 创建 Worker: \(worker.name), type=\(descriptor.id)")
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

    private func makeWorker(descriptor: WorkerAgentDescriptor, config: LLMConfig) -> WorkerAgent {
        WorkerAgent(
            name: descriptor.displayName,
            typeId: descriptor.id,
            description: descriptor.roleDescription,
            specialty: descriptor.specialty,
            config: config,
            systemPrompt: descriptor.systemPrompt
        )
    }

    private func resolveDescriptor(typeId: String) async -> WorkerAgentDescriptor? {
        await MainActor.run {
            PluginProvider.shared.getWorkerAgentDescriptors().first { $0.id == typeId }
        }
    }
}
