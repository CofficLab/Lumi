import DownloadKit
import Foundation
import LumiCoreKit
import SuperLogKit

/// 重试下载工具
///
/// 重试一个失败的下载任务。
public struct RetryDownloadTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔄"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "retry_download",
        displayName: LumiPluginLocalization.string("Retry Download", bundle: .module),
        description: LumiPluginLocalization.string(
            "Retry a failed or cancelled download task. The system will resume from the breakpoint, not restart from beginning.",
            bundle: .module
        )
    )

    private let manager: DownloadManager
    /// 用于存储已失败/取消任务的信息，以便重试时使用
    private var failedTasks: [String: FailedTaskInfo] = [:]

    private struct FailedTaskInfo {
        let url: URL
        let destination: URL
        let expectedSize: Int64?
    }

    public init(manager: DownloadManager) {
        self.manager = manager
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task_id": .object([
                    "type": .string("string"),
                    "description": .string("要重试的任务 ID")
                ])
            ]),
            "required": .array([.string("task_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        if let taskId = arguments["task_id"]?.stringValue {
            return "重试下载: \(taskId.prefix(8))..."
        }
        return "重试下载"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let taskId = arguments["task_id"]?.stringValue else {
            return "❌ 错误：task_id 参数必需"
        }

        // 先检查状态
        guard let state = await manager.state(for: taskId) else {
            return "❌ 未找到任务: \(taskId)\n\n请使用 list_downloads 查看当前任务列表。"
        }

        // 只有失败或取消的任务才能重试
        switch state {
        case .failed, .cancelled:
            break
        case .completed:
            return "⚠️ 任务已完成，无需重试\n任务 ID: \(taskId)"
        case .downloading, .pending:
            return "⚠️ 任务正在进行中，无法重试\n任务 ID: \(taskId)"
        }

        // 从保存的信息中获取任务详情
        guard let taskInfo = failedTasks[taskId] else {
            return "❌ 无法获取任务详情: \(taskId)"
        }

        // 重新创建下载任务
        let newTaskId = UUID().uuidString
        let newTask = DownloadTask(
            id: newTaskId,
            url: taskInfo.url,
            destination: taskInfo.destination,
            expectedSize: taskInfo.expectedSize
        )

        do {
            let finalURL = try await manager.download(newTask)
            return """
            ✅ 重试成功
            文件名: \(finalURL.lastPathComponent)
            任务 ID: \(newTaskId)
            路径: \(finalURL.path)
            """
        } catch {
            return "❌ 重试失败: \(error.localizedDescription)\n任务 ID: \(newTaskId)"
        }
    }
}
