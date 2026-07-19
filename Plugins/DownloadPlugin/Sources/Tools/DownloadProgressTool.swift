import DownloadKit
import Foundation
import LumiKernel
import SuperLogKit

/// 下载进度查询工具
///
/// 查询下载任务的当前进度。
public struct DownloadProgressTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "download_progress",
        displayName: LumiPluginLocalization.string("Download Progress", bundle: .module),
        description: LumiPluginLocalization.string(
            "Query detailed progress for a specific download task. Returns percentage, downloaded size, speed, and more.",
            bundle: .module
        )
    )

    private let manager: DownloadManager

    public init(manager: DownloadManager) {
        self.manager = manager
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task_id": .object([
                    "type": .string("string"),
                    "description": .string("任务 ID")
                ])
            ]),
            "required": .array([.string("task_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        if let taskId = arguments["task_id"]?.stringValue {
            return "查询下载进度: \(taskId.prefix(8))..."
        }
        return "查询下载进度"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let taskId = arguments["task_id"]?.stringValue else {
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
            return "✅ 任务已完成\n任务 ID: \(taskId)"

        case .failed(let error):
            return "❌ 任务失败: \(error.localizedDescription)\n任务 ID: \(taskId)"

        case .cancelled:
            return "⛔ 任务已取消\n任务 ID: \(taskId)"
        }
    }
}

extension DownloadProgressTool {
    fileprivate static func formatBytes(_ bytes: Int64) -> String {
        if bytes > 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        } else if bytes > 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        } else if bytes > 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        }
        return "\(bytes) B"
    }
}
