import KitAgentTool
import Foundation

/// 停止一个正在运行的后台任务。
///
/// 停止语义复用 KitShell 的进程树终止（SIGTERM → 宽限 → SIGKILL）：
/// 后台命令常常带子进程（编译器、测试 runner），只杀直接子进程会留下孤儿。
public struct StopBackgroundTaskTool: SuperAgentTool, @unchecked Sendable {
    public let name = "stop_background_task"
    public let executionCapability: ToolExecutionCapability = .serialSideEffect

    private let registryProvider: @MainActor @Sendable () -> BackgroundTaskRegistry?

    public init(
        registryProvider: @escaping @MainActor @Sendable () -> BackgroundTaskRegistry? = { nil }
    ) {
        self.registryProvider = registryProvider
    }

    public func description(for language: LanguagePreference) -> String {
        "Stop a background task started by run_command. The whole process tree is terminated. Returns the task's final state."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "task_id": ["type": "string", "description": "The background task ID returned by run_command when it moved the command to the background."],
            ],
            "required": ["task_id"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let taskID = arguments.stringValue("task_id") else { return "停止后台任务" }
        return "停止后台任务 \(taskID.prefix(8))"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let taskID = arguments.stringValue("task_id"),
              !taskID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing 'task_id' argument"
            )
        }

        guard let registry = await registryProvider() else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Background task registry is unavailable"
            )
        }

        guard let record = await registry.task(for: taskID) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "No background task with ID '\(taskID)'"
            )
        }

        let stopped = await registry.stop(taskID: taskID)
        guard stopped else {
            // 任务已经结束：这不是失败，只是没有可停的东西。告诉模型真实状态，
            // 让它据此继续，而不是报一个误导性的错误。
            return "Background task \(taskID) is already \(record.status.rawValue); nothing to stop."
        }

        let updated = await registry.task(for: taskID)
        return "Background task \(taskID) stopped. Status: \(updated?.status.rawValue ?? "stopped")."
    }
}
