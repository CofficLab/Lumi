import Foundation
import KernelLumi

/// 查询音乐生成历史记录详情。
///
/// - Tool ID: `get_music`
/// - Emoji: 🔍
/// - 通过 recordID 查询单条记录的完整信息。
public struct MiniMaxGetMusicTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "get_music",
        displayName: LumiPluginLocalization.string("Music Detail", bundle: .module),
        description: LumiPluginLocalization.string(
            "Get detailed information of a specific music generation record by its record ID.",
            bundle: .module
        )
    )

    public nonisolated static let emoji = "🔍"

    private let store: MiniMaxMusicRecordStore

    init(store: MiniMaxMusicRecordStore) {
        self.store = store
    }

    public var name: String { "get_music" }

    public var toolDescription: String { Self.info.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "recordID": .object([
                    "type": .string("string"),
                    "description": .string("The record ID to query. You can get record IDs from minimax_list_music."),
                ]),
            ]),
            "required": .array([.string("recordID")]),
        ])
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        kernel: KernelLumi
    ) async throws -> String {
        guard let recordID = arguments["recordID"]?.stringValue, !recordID.isEmpty else {
            return "**Error:** `recordID` is required. Use minimax_list_music to get available record IDs."
        }

        guard let record = await store.fetchByID(recordID: recordID) else {
            return "**Error:** No record found with ID: \(recordID)"
        }

        let formatter = ISO8601DateFormatter()
        var lines = [
            "## 🔍 Music Record Detail",
            "",
            "- **Record ID:** \(record.id)",
            "- **Status:** \(record.status)",
            "- **Model:** \(record.model)",
            "- **Instrumental:** \(record.isInstrumental ? "Yes" : "No")",
            "- **Lyrics Optimizer:** \(record.lyricsOptimizer ? "Yes" : "No")",
            "- **AIGC Watermark:** \(record.aigcWatermark ? "Yes" : "No")",
            "- **Created At:** \(formatter.string(from: record.createdAt))",
        ]

        if let prompt = record.prompt {
            lines.append("- **Prompt:** \(prompt)")
        }
        if let taskID = record.traceId {
            lines.append("- **Trace ID:** \(taskID)")
        }
        if let completedAt = record.completedAt {
            let elapsed = completedAt.timeIntervalSince(record.createdAt)
            lines.append("- **Completed At:** \(formatter.string(from: completedAt)) (\(String(format: "%.1f", elapsed))s)")
        }

        // 音频信息
        if let durationMs = record.durationMs {
            let seconds = Double(durationMs) / 1000.0
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            lines.append("- **Duration:** \(minutes):\(String(format: "%02d", secs))")
        }
        if let sampleRate = record.sampleRate {
            lines.append("- **Sample Rate:** \(sampleRate) Hz")
        }
        if let bitrate = record.bitrate {
            lines.append("- **Bitrate:** \(bitrate / 1000) kbps")
        }
        if let channels = record.channels {
            lines.append("- **Channels:** \(channels)")
        }
        if let fileSize = record.fileSize {
            lines.append("- **File Size:** \(formatByteCount(Int64(fileSize)))")
        }
        if let audioFormat = record.audioFormat {
            lines.append("- **Audio Format:** \(audioFormat)")
        }

        // 音频 URL
        if let audioURL = record.audioURL, let url = URL(string: audioURL) {
            lines.append("")
            lines.append("### 🎧 Audio")
            lines.append("")
            lines.append("[Listen / Download](\(url.absoluteString))")
            if let expiresAt = record.audioURLExpiresAt {
                if expiresAt > Date() {
                    let remaining = Int(expiresAt.timeIntervalSince(Date()) / 3600)
                    lines.append("> Link expires in ~\(remaining) hours")
                } else {
                    lines.append("> Link expired ⚠️")
                }
            }
        }

        // 歌词
        if let lyrics = record.lyrics {
            lines.append("")
            lines.append("### Lyrics")
            lines.append("")
            lines.append(lyrics)
        }

        // 翻唱参考
        if let audioUrl = record.audioUrl {
            lines.append("")
            lines.append("### Cover Reference")
            lines.append("- **Reference Audio:** \(audioUrl)")
        }
        if let coverFeatureId = record.coverFeatureId {
            lines.append("- **Cover Feature ID:** \(coverFeatureId)")
        }

        // 错误信息
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
