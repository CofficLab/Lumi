import DownloadKit
import Foundation
import LumiCoreKit
import SuperLogKit

/// 取消下载工具
///
/// 取消正在进行的下载任务。
public struct CancelDownloadTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "⛔"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "cancel_download",
        displayName: LumiPluginLocalization.string("Cancel Download", bundle: .module),
        description: LumiPluginLocalization.string(
            "Cancel an ongoing download task. Task ID is returned by download_file or download_batch.",
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
                    "description": .string("要取消的任务 ID")
                ])
            ]),
            "required": .array([.string("task_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        if let taskId = arguments["task_id"]?.stringValue {
            return "取消下载: \(taskId.prefix(8))..."
        }
        return "取消下载"
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
