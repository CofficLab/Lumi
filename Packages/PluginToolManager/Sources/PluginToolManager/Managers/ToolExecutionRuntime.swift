import Foundation
import KitAgentTool

enum ToolExecutionOutcome: Sendable {
    case completed(ToolCallResult)
    case failed(String)
    case cancelled(String)
    case timedOut(String)
}

/// 持有实际工具执行 Task 的后台 runtime。
///
/// Runtime 不读取 ToolManager 的注册表；工具和参数在 start 时已经冻结，
/// 因此工具执行期间不会依赖 MainActor 状态。
actor ToolExecutionRuntime {
    private var tasks: [String: Task<ToolExecutionOutcome, Never>] = [:]
    private var cancellationRequests: Set<String> = []

    func start(
        jobID: String,
        operation: @escaping @Sendable () async -> ToolExecutionOutcome
    ) {
        guard tasks[jobID] == nil else { return }
        if cancellationRequests.remove(jobID) != nil {
            tasks[jobID] = Task.detached {
                .cancelled("Tool execution cancelled before it started.")
            }
            return
        }
        tasks[jobID] = Task.detached(priority: .userInitiated, operation: operation)
    }

    func cancel(jobID: String) {
        if let task = tasks[jobID] {
            task.cancel()
        } else {
            cancellationRequests.insert(jobID)
        }
    }

    func wait(for jobID: String) async -> ToolExecutionOutcome? {
        guard let task = tasks[jobID] else { return nil }
        let outcome = await task.value
        tasks.removeValue(forKey: jobID)
        cancellationRequests.remove(jobID)
        return outcome
    }
}
