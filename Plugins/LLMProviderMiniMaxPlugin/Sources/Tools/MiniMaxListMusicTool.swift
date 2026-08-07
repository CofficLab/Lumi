import Foundation
import LumiKernel

/// 查询音乐生成历史记录列表。
///
/// - Tool ID: `list_music`
/// - Emoji: 📋
/// - 支持分页（通过 `beforeID` 游标）和状态过滤。
public struct MiniMaxListMusicTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "list_music",
        displayName: LumiPluginLocalization.string("Music History", bundle: .module),
        description: LumiPluginLocalization.string(
            "List music generation history records. Supports pagination via beforeID cursor and optional status filter (pending/success/failed/cancelled).",
            bundle: .module
        )
    )

    public nonisolated static let emoji = "📋"

    private let store: MiniMaxMusicRecordStore

    init(store: MiniMaxMusicRecordStore) {
        self.store = store
    }

    public var name: String { "list_music" }

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
                    "description": .string("Filter by status: pending, success, failed, cancelled. Omit to return all statuses."),
                ]),
            ]),
        ])
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        kernel: LumiKernel
    ) async throws -> String {
        let limit = intArgument(arguments["limit"]) ?? 10
        let clampedLimit = min(max(limit, 1), 50)
        let beforeID = arguments["beforeID"]?.stringValue
        let statusRaw = arguments["status"]?.stringValue

        let records: [MiniMaxMusicRecordDTO]
        if let statusRaw, let status = MiniMaxMusicRecordStatus(rawValue: statusRaw) {
            records = await fetchFiltered(limit: clampedLimit, beforeID: beforeID, status: status)
        } else {
            records = await store.fetchPage(limit: clampedLimit, beforeID: beforeID)
        }

        guard !records.isEmpty else {
            return "No music generation records found."
        }

        var lines: [String] = ["## 📋 Music Generation History (\(records.count) records)", ""]
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
        status: MiniMaxMusicRecordStatus
    ) async -> [MiniMaxMusicRecordDTO] {
        let all = await store.fetchPage(limit: limit, beforeID: beforeID)
        let statusRaw = status.rawValue
        return all.filter { $0.status == statusRaw }
    }

    private func formatRecord(_ record: MiniMaxMusicRecordDTO, index: Int) -> [String] {
        let statusEmoji: String
        switch MiniMaxMusicRecordStatus(rawValue: record.status) {
        case .success: statusEmoji = "✅"
        case .failed: statusEmoji = "❌"
        case .cancelled: statusEmoji = "🚫"
        case .pending, .none: statusEmoji = "🕐"
        }

        var lines = [
            "### \(index). \(statusEmoji) \(record.model) — \(record.status)",
            "- **ID:** \(record.id)",
        ]

        if let prompt = record.prompt {
            lines.append("- **Prompt:** \(prompt)")
        }
        if record.isInstrumental {
            lines.append("- **Instrumental:** Yes")
        }

        let formatter = ISO8601DateFormatter()
        lines.append("- **Created:** \(formatter.string(from: record.createdAt))")

        if let completedAt = record.completedAt {
            let elapsed = completedAt.timeIntervalSince(record.createdAt)
            lines.append("- **Completed:** \(formatter.string(from: completedAt)) (\(String(format: "%.1f", elapsed))s)")
        }

        if let durationMs = record.durationMs {
            let seconds = Double(durationMs) / 1000.0
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            lines.append("- **Duration:** \(minutes):\(String(format: "%02d", secs))")
        }

        if let audioURL = record.audioURL {
            lines.append("- **Audio:** [Listen](\(audioURL))")
            if let expiresAt = record.audioURLExpiresAt {
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
