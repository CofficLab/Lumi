import Foundation
import KernelLumi

/// 查询视频生成历史记录列表。
///
/// - Tool ID: `list_videos`
/// - Emoji: 📋
/// - 支持分页（通过 `beforeID` 游标）和状态过滤。
public struct MiniMaxListVideosTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "list_videos",
        displayName: LumiPluginLocalization.string("Video History", bundle: .module),
        description: LumiPluginLocalization.string(
            "List video generation history records. Supports pagination via beforeID cursor and optional status filter (pending/generating/success/failed/cancelled).",
            bundle: .module
        )
    )

    public nonisolated static let emoji = "📋"

    private let store: MiniMaxVideoRecordStore

    init(store: MiniMaxVideoRecordStore) {
        self.store = store
    }

    public var name: String { "list_videos" }

    public var toolDescription: String { Self.info.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of records to return (default: 10, max: 50)."),
                ]),
                "beforeID": .object([
                    "type": .string("string"),
                    "description": .string("Pagination cursor: return records created before the record with this ID."),
                ]),
                "status": .object([
                    "type": .string("string"),
                    "description": .string("Filter by status: pending, generating, success, failed, cancelled. Omit to return all statuses."),
                ]),
            ]),
        ])
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        kernel: KernelLumi
    ) async throws -> String {
        let limit = intArgument(arguments["limit"]) ?? 10
        let clampedLimit = min(max(limit, 1), 50)
        let beforeID = arguments["beforeID"]?.stringValue
        let statusRaw = arguments["status"]?.stringValue

        let records: [MiniMaxVideoRecordDTO]
        if let statusRaw, let status = MiniMaxVideoRecordStatus(rawValue: statusRaw) {
            records = await fetchFiltered(limit: clampedLimit, beforeID: beforeID, status: status)
        } else {
            records = await store.fetchPage(limit: clampedLimit, beforeID: beforeID)
        }

        guard !records.isEmpty else {
            return "No video generation records found."
        }

        var lines: [String] = ["## 📋 Video Generation History (\(records.count) records)", ""]
        for (index, record) in records.enumerated() {
            lines.append(contentsOf: formatRecord(record, index: index + 1))
            lines.append("")
        }

        if let lastRecord = records.last {
            lines.append("> Use `beforeID: \"\(lastRecord.id)\"` to fetch older records.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func fetchFiltered(
        limit: Int,
        beforeID: String?,
        status: MiniMaxVideoRecordStatus
    ) async -> [MiniMaxVideoRecordDTO] {
        let all = await store.fetchPage(limit: limit, beforeID: beforeID)
        let statusRaw = status.rawValue
        return all.filter { $0.status == statusRaw }
    }

    private func formatRecord(_ record: MiniMaxVideoRecordDTO, index: Int) -> [String] {
        let statusEmoji: String
        switch MiniMaxVideoRecordStatus(rawValue: record.status) {
        case .success: statusEmoji = "✅"
        case .failed: statusEmoji = "❌"
        case .cancelled: statusEmoji = "🚫"
        case .generating: statusEmoji = "⏳"
        case .pending, .none: statusEmoji = "🕐"
        }

        var lines = [
            "### \(index). \(statusEmoji) \(record.model) — \(record.status)",
            "- **ID:** \(record.id)",
            "- **Prompt:** \(record.prompt)",
            "- **Duration:** \(record.duration)s · **Resolution:** \(record.resolution)",
        ]

        let formatter = ISO8601DateFormatter()
        lines.append("- **Created:** \(formatter.string(from: record.createdAt))")

        if let completedAt = record.completedAt {
            let elapsed = completedAt.timeIntervalSince(record.createdAt)
            lines.append("- **Completed:** \(formatter.string(from: completedAt)) (\(String(format: "%.1f", elapsed))s)")
        }

        if let downloadURL = record.downloadURL {
            lines.append("- **Download:** [\(record.fileName ?? "video.mp4")](\(downloadURL))")
            if let expiresAt = record.downloadURLExpiresAt {
                if expiresAt > Date() {
                    let remaining = Int(expiresAt.timeIntervalSince(Date()) / 3600)
                    lines.append("- **Link expires in:** ~\(remaining)h")
                } else {
                    lines.append("- **Link:** expired ⚠️")
                }
            }
        }

        if let error = record.errorMessage {
            lines.append("- **Error:** \(error)")
        }

        return lines
    }

    private func intArgument(_ value: LumiJSONValue?) -> Int? {
        switch value {
        case .int(let intValue): return intValue
        case .double(let doubleValue): return Int(doubleValue)
        default: return nil
        }
    }
}
