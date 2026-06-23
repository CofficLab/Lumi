import AgentToolKit
import DownloadKit
import Foundation
import SuperLogKit

/// 取消下载工具
///
/// 取消正在进行的下载任务。
public struct CancelDownloadTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "⛔"
    public nonisolated static let verbose: Bool = false

    private let manager: DownloadManager

    public init(manager: DownloadManager) {
        self.manager = manager
    }

    public let name = "cancel_download"

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "取消正在进行的下载任务。任务 ID 由 download_file 或 download_batch 返回。"
        case .english:
            return "Cancel an ongoing download task. Task ID is returned by download_file or download_batch."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "task_id": [
                    "type": "string",
                    "description": "要取消的任务 ID",
                ],
            ],
            "required": ["task_id"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let taskId = arguments["task_id"]?.value as? String {
            return "取消下载: \(taskId.prefix(8))..."
        }
        return "取消下载"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let taskId = arguments["task_id"]?.value as? String else {
            return "❌ 错误：task_id 参数必需"
        }

        guard let state = await manager.state(for: taskId) else {
            return "❌ 未找到任务: \(taskId)\n\n请使用 list_downloads 查看当前任务列表。"
        }

        // 只有进行中的任务才能取消
        switch state {
        case .downloading:
            await manager.cancel(taskId: taskId)
            return "✅ 已取消下载\n任务 ID: \(taskId)"

        case .pending:
            await manager.cancel(taskId: taskId)
            return "✅ 已移除等待中的任务\n任务 ID: \(taskId)"

        case .completed:
            return "⚠️ 任务已完成，无需取消\n任务 ID: \(taskId)"

        case .cancelled:
            return "⚠️ 任务已被取消\n任务 ID: \(taskId)"

        case .failed:
            return "⚠️ 任务已失败，无需取消\n任务 ID: \(taskId)"
        }
    }
}
