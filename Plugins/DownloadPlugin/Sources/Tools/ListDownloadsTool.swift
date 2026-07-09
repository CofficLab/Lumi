import DownloadKit
import Foundation
import LumiCoreKit
import SuperLogKit

/// 列出下载任务工具
///
/// 列出所有当前下载任务及其状态。
public struct ListDownloadsTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "list_downloads",
        displayName: LumiPluginLocalization.string("List Downloads", bundle: .module),
        description: LumiPluginLocalization.string(
            "List all current download tasks and their status, including pending, downloading, completed, failed, and cancelled tasks.",
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
            "properties": .object([:]),
            "required": .array([])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "列出所有下载任务"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let states = await manager.allTaskStates()

        if states.isEmpty {
            return "📋 当前没有下载任务"
        }

        var lines: [String] = ["📋 当前下载任务:", ""]
        
        for (taskId, state) in states {
            let status: String
            switch state {
            case .pending:
                status = "⏳ 等待中"
            case .downloading(let progress):
                let percent = progress.fractionCompleted * 100
                let speedMB = (progress.bytesPerSecond ?? 0) / 1_048_576
                status = String(format: "⬇️ 下载中 %.1f%% (%.1f MB/s)", percent, speedMB)
            case .completed:
                status = "✅ 完成"
            case .failed(let error):
                status = "❌ 失败: \(error.localizedDescription)"
            case .cancelled:
                status = "⛔ 已取消"
            }

            lines.append("\(status) ")
            lines.append("   ID: \(taskId)")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
