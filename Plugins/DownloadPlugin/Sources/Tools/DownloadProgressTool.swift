import AgentToolKit
import DownloadKit
import Foundation
import SuperLogKit

/// 查询下载进度工具
///
/// 返回指定下载任务的详细进度信息，包括百分比、已下载大小、速度等。
public struct DownloadProgressTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = false

    private let manager: DownloadManager

    public init(manager: DownloadManager) {
        self.manager = manager
    }

    public let name = "download_progress"

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查询指定下载任务的详细进度信息。返回百分比、已下载大小、下载速度等。"
        case .english:
            return "Query detailed progress for a specific download task. Returns percentage, downloaded size, speed, and more."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "task_id": [
                    "type": "string",
                    "description": "任务 ID（由 download_file 或 download_batch 返回）",
                ],
            ],
            "required": ["task_id"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let taskId = arguments["task_id"]?.value as? String {
            return "查询进度: \(taskId.prefix(8))..."
        }
        return "查询下载进度"
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
        case .pending:
            return "⏳ 任务等待中\n任务 ID: \(taskId)"

        case .downloading(let progress):
            let percent = progress.fractionCompleted * 100
            let downloadedMB = Double(progress.downloadedBytes) / 1_048_576
            let totalMB = progress.totalBytes.map { Double($0) / 1_048_576 }
            let speedMB = (progress.bytesPerSecond ?? 0) / 1_048_576

            var result = String(format: "⬇️ 下载中\n进度: %.1f%%\n", percent)
            result += String(format: "已下载: %.2f MB", downloadedMB)
            if let total = totalMB {
                result += String(format: " / %.2f MB\n", total)
            } else {
                result += "\n"
            }
            result += String(format: "速度: %.2f MB/s\n", speedMB)
            result += "任务 ID: \(taskId)"

            return result

        case .completed:
            return "✅ 下载已完成\n任务 ID: \(taskId)"

        case .failed(let error):
            return "❌ 下载失败\n任务 ID: \(taskId)\n错误: \(error.localizedDescription)"

        case .cancelled:
            return "⛔ 下载已取消\n任务 ID: \(taskId)"
        }
    }
}
