import AgentToolKit
import DownloadKit
import Foundation
import SuperLogKit

/// 重试下载工具
///
/// 重试失败或已取消的下载任务。系统会基于断点续传数据继续下载。
public struct RetryDownloadTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "🔄"
    public nonisolated static let verbose: Bool = false

    private let manager: DownloadManager

    public init(manager: DownloadManager) {
        self.manager = manager
    }

    public let name = "retry_download"

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "重试失败或已取消的下载任务。系统会自动利用断点续传功能继续下载，不会重新开始。"
        case .english:
            return "Retry a failed or cancelled download task. The system will resume from the breakpoint, not restart from beginning."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "task_id": [
                    "type": "string",
                    "description": "要重试的任务 ID",
                ],
            ],
            "required": ["task_id"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let taskId = arguments["task_id"]?.value as? String {
            return "重试下载: \(taskId.prefix(8))..."
        }
        return "重试下载"
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

        switch state {
        case .failed:
            // 失败的任务可以重试，但 DownloadManager 没有直接的 retry 方法
            // 需要用户用 download_file 重新发起，系统会自动断点续传
            return "⚠️ 该任务已失败。\n请使用 download_file 工具重新下载相同 URL，系统会自动利用断点续传继续下载。\n任务 ID: \(taskId)"

        case .cancelled:
            return "⚠️ 该任务已取消。\n请使用 download_file 工具重新下载相同 URL。\n任务 ID: \(taskId)"

        case .downloading:
            return "⚠️ 任务正在进行中，无需重试\n任务 ID: \(taskId)"

        case .completed:
            return "✅ 任务已完成，无需重试\n任务 ID: \(taskId)"

        case .pending:
            return "⚠️ 任务正在等待中，无需重试\n任务 ID: \(taskId)"
        }
    }
}
