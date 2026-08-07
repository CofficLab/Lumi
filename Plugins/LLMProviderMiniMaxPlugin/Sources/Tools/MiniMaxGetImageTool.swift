import Foundation
import LumiKernel

/// 查询图片生成历史记录详情。
///
/// - Tool ID: `get_image`
/// - Emoji: 🔍
/// - 通过 recordID 查询单条记录的完整信息。
public struct MiniMaxGetImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "get_image",
        displayName: LumiPluginLocalization.string("Image Detail", bundle: .module),
        description: LumiPluginLocalization.string(
            "Get detailed information of a specific image generation record by its record ID.",
            bundle: .module
        )
    )

    public nonisolated static let emoji = "🔍"

    private let store: MiniMaxImageRecordStore

    init(store: MiniMaxImageRecordStore) {
        self.store = store
    }

    public var name: String { "get_image" }

    public var toolDescription: String { Self.info.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "recordID": .object([
                    "type": .string("string"),
                    "description": .string("The record ID to query. You can get record IDs from minimax_list_images."),
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
            return "**Error:** `recordID` is required. Use minimax_list_images to get available record IDs."
        }

        guard let record = await store.fetchByID(recordID: recordID) else {
            return "**Error:** No record found with ID: \(recordID)"
        }

        let formatter = ISO8601DateFormatter()
        var lines = [
            "## 🔍 Image Record Detail",
            "",
            "- **Record ID:** \(record.id)",
            "- **Status:** \(record.status)",
            "- **Model:** \(record.model)",
            "- **Prompt:** \(record.prompt)",
            "- **Requested Images:** \(record.n)",
            "- **Success Count:** \(record.successCount)",
            "- **Failed Count:** \(record.failedCount)",
        ]

        if let aspectRatio = record.aspectRatio {
            lines.append("- **Aspect Ratio:** \(aspectRatio)")
        }
        if let subjectRefJSON = record.subjectReference {
            lines.append("- **Subject Reference:** \(subjectRefJSON)")
        }
        if let styleType = record.styleType {
            lines.append("- **Style:** \(styleType)")
        }
        if let styleWeight = record.styleWeight {
            lines.append("- **Style Weight:** \(styleWeight)")
        }
        lines.append("- **Prompt Optimizer:** \(record.promptOptimizer ? "Yes" : "No")")
        lines.append("- **AIGC Watermark:** \(record.aigcWatermark ? "Yes" : "No")")
        lines.append("- **Created At:** \(formatter.string(from: record.createdAt))")

        if let taskID = record.taskID {
            lines.append("- **Task ID:** \(taskID)")
        }

        if let completedAt = record.completedAt {
            let elapsed = completedAt.timeIntervalSince(record.createdAt)
            lines.append("- **Completed At:** \(formatter.string(from: completedAt)) (\(String(format: "%.1f", elapsed))s)")
        }

        let imageURLs = record.parsedImageURLs
        if !imageURLs.isEmpty {
            lines.append("")
            lines.append("### Generated Images")
            lines.append("")
            for (index, url) in imageURLs.enumerated() {
                lines.append("**Image \(index + 1):**")
                lines.append("> \(url.absoluteString)")
                lines.append("")
            }
            if let expiresAt = record.imageURLExpiresAt {
                if expiresAt > Date() {
                    let remaining = Int(expiresAt.timeIntervalSince(Date()) / 3600)
                    lines.append("> Links expire in ~\(remaining) hours")
                } else {
                    lines.append("> Links expired ⚠️")
                }
            }
        }

        if let errorMessage = record.errorMessage {
            lines.append("")
            lines.append("### ❌ Error")
            lines.append(errorMessage)
        }

        return lines.joined(separator: "\n")
    }
}
