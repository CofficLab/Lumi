import Foundation
import LumiKernel

/// 查询视频生成历史记录详情。
///
/// - Tool ID: `get_video`
/// - Emoji: 🔍
/// - 通过 recordID 查询单条记录的完整信息。
public struct MiniMaxGetVideoTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "get_video",
        displayName: LumiPluginLocalization.string("Video Detail", bundle: .module),
        description: LumiPluginLocalization.string(
            "Get detailed information of a specific video generation record by its record ID.",
            bundle: .module
        )
    )

    public nonisolated static let emoji = "🔍"

    private let store: MiniMaxVideoRecordStore

    init(store: MiniMaxVideoRecordStore) {
        self.store = store
    }

    public var name: String { "get_video" }

    public var toolDescription: String { Self.info.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "recordID": .object([
                    "type": .string("string"),
                    "description": .string("The record ID to query. You can get record IDs from minimax_list_videos."),
                ]),
            ]),
            "required": .array([.string("recordID")]),
        ])
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        kernel: LumiKernel
    ) async throws -> String {
        guard let recordID = arguments["recordID"]?.stringValue, !recordID.isEmpty else {
            return "**Error:** `recordID` is required. Use minimax_list_videos to get available record IDs."
        }

        guard let record = await store.fetchByID(recordID: recordID) else {
            return "**Error:** No record found with ID: \(recordID)"
        }

        let formatter = ISO8601DateFormatter()
        var lines = [
            "## 🔍 Video Record Detail",
            "",
            "- **Record ID:** \(record.id)",
            "- **Status:** \(record.status)",
            "- **Model:** \(record.model)",
            "- **Prompt:** \(record.prompt)",
            "- **Duration:** \(record.duration)s",
            "- **Resolution:** \(record.resolution)",
            "- **Prompt Optimizer:** \(record.promptOptimizer ? "Yes" : "No")",
            "- **Fast Pretreatment:** \(record.fastPretreatment ? "Yes" : "No")",
            "- **AIGC Watermark:** \(record.aigcWatermark ? "Yes" : "No")",
            "- **Created At:** \(formatter.string(from: record.createdAt))",
        ]

        if let taskID = record.taskID {
            lines.append("- **Task ID:** \(taskID)")
        }

        if let completedAt = record.completedAt {
            let elapsed = completedAt.timeIntervalSince(record.createdAt)
            lines.append("- **Completed At:** \(formatter.string(from: completedAt)) (\(String(format: "%.1f", elapsed))s)")
        }

        if let downloadURL = record.downloadURL {
            let fileName = record.fileName ?? "video.mp4"
            lines.append("- **Download URL:** [\(fileName)](\(downloadURL))")
            if let expiresAt = record.downloadURLExpiresAt {
                if expiresAt > Date() {
                    let remaining = Int(expiresAt.timeIntervalSince(Date()) / 3600)
                    lines.append("- **Link Expires In:** ~\(remaining)h")
                } else {
                    lines.append("- **Link Status:** expired ⚠️")
                }
            }
        }

        if let byteCount = record.byteCount {
            let sizeStr = formatByteCount(byteCount)
            lines.append("- **File Size:** \(sizeStr)")
        }

        if let errorMessage = record.errorMessage {
            lines.append("")
            lines.append("### ❌ Error")
            lines.append(errorMessage)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func formatByteCount(_ byteCount: Int64) -> String {
        if byteCount < 1024 {
            return "\(byteCount) B"
        } else if byteCount < 1024 * 1024 {
            return String(format: "%.1f KB", Double(byteCount) / 1024)
        } else {
            return String(format: "%.1f MB", Double(byteCount) / (1024 * 1024))
        }
    }
}
