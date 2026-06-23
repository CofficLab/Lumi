import AgentToolKit
import DownloadKit
import Foundation
import SuperLogKit

/// 列出下载任务工具
///
/// 返回当前所有下载任务的简要状态列表。
public struct ListDownloadsTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = false

    private let manager: DownloadManager

    public init(manager: DownloadManager) {
        self.manager = manager
    }

    public let name = "list_downloads"

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "列出所有当前活动的下载任务及其状态。包括等待中、下载中、已完成、失败和已取消的任务。"
        case .english:
            return "List all current download tasks and their status, including pending, downloading, completed, failed, and cancelled tasks."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:],
            "required": [] as [String],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "列出下载任务"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let states = await manager.allTaskStates()

        if states.isEmpty {
            return "📋 当前没有下载任务"
        }

        var lines: [String] = []
        var pendingCount = 0
        var downloadingCount = 0
        var completedCount = 0
        var failedCount = 0
        var cancelledCount = 0

        for (taskId, state) in states {
            let statusLabel: String
            switch state {
            case .pending:
                statusLabel = "⏳ 等待中"
                pendingCount += 1
            case .downloading(let progress):
                let percent = progress.fractionCompleted * 100
                let speedMB = (progress.bytesPerSecond ?? 0) / 1_048_576
                statusLabel = String(format: "⬇️ 下载中 %.1f%% (%.1f MB/s)", percent, speedMB)
                downloadingCount += 1
            case .completed:
                statusLabel = "✅ 完成"
                completedCount += 1
            case .failed(let error):
                statusLabel = "❌ 失败: \(error.localizedDescription)"
                failedCount += 1
            case .cancelled:
                statusLabel = "⛔ 已取消"
                cancelledCount += 1
            }

            lines.append("• \(taskId.prefix(8))... — \(statusLabel)")
        }

        var header = "📋 下载任务 (共 \(states.count) 个)\n"
        header += "下载中: \(downloadingCount) | 等待: \(pendingCount) | 完成: \(completedCount) | 失败: \(failedCount) | 取消: \(cancelledCount)\n\n"

        return header + lines.joined(separator: "\n")
    }
}
