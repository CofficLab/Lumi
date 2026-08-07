import Foundation
import LumiKernel
import LLMKit

/// 音乐生成工具：通过 MiniMax API 生成音乐，并把音频下载链接（24 小时有效）返回给调用方。
///
/// 单次 POST 请求，直接返回音频 URL。
///
/// - Tool ID: `generate_music`
/// - Emoji: 🎵
/// - Tags: `.network`, `"generative"`
/// - API Key: 复用 TokenPlan 的 `DevAssistant_ApiKey_MiniMax`
public struct MiniMaxMusicTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "generate_music",
        displayName: LumiPluginLocalization.string("Music", bundle: .module),
        description: LumiPluginLocalization.string(
            "Generate music from text descriptions and lyrics using MiniMax AI. Supports text-to-music (with lyrics or instrumental) and audio cover generation. Returns a temporary audio download URL (valid for 24 hours).",
            bundle: .module
        )
    )

    public static let tags: Set<LumiToolTag> = [
        .network,
        "generative",
    ]

    public nonisolated static let emoji = "🎵"

    private let client: any MiniMaxMusicClientProtocol
    private let recordStore: MiniMaxMusicRecordStore?

    // MARK: - Init

    init(
        client: any MiniMaxMusicClientProtocol = MiniMaxMusicClient(apiKeyProvider: {
            APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: "DevAssistant_ApiKey_MiniMax")
        }),
        recordStore: MiniMaxMusicRecordStore? = nil
    ) {
        self.client = client
        self.recordStore = recordStore
    }

    // MARK: - LumiAgentTool

    public var name: String { "generate_music" }

    public var toolDescription: String { Self.info.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "prompt": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Music description specifying style, mood, and scene. Example: '流行音乐, 难过, 适合在下雨的晚上'. Required for instrumental mode (1-2000 chars), optional for vocal mode (0-2000 chars)."
                    ),
                ]),
                "lyrics": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Song lyrics separated by '\\n'. Supports structure tags: [Intro], [Verse], [Pre Chorus], [Chorus], [Interlude], [Bridge], [Outro], [Hook], [Inst], [Solo]. Required for non-instrumental mode (1-3500 chars). Optional for instrumental mode."
                    ),
                ]),
                "model": .object([
                    "type": .string("string"),
                    "description": .string("Music generation model. Default: music-3.0-free. Options: music-3.0, music-2.6, music-cover, music-3.0-free, music-2.6-free, music-cover-free."),
                    "enum": .array([
                        .string("music-3.0"),
                        .string("music-2.6"),
                        .string("music-cover"),
                        .string("music-3.0-free"),
                        .string("music-2.6-free"),
                        .string("music-cover-free"),
                    ]),
                ]),
                "is_instrumental": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to generate instrumental only (no vocals). Only for music-3.0/2.6 models. Default: false."),
                ]),
                "lyrics_optimizer": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to auto-generate lyrics from prompt description. Only for music-3.0/2.6 models. Default: false."),
                ]),
                "audio_url": .object([
                    "type": .string("string"),
                    "description": .string("Reference audio URL for cover generation. Only for music-cover models. Audio requirements: 6s-6min, max 50MB. Mutually exclusive with audio_base64 and cover_feature_id."),
                ]),
                "audio_format": .object([
                    "type": .string("string"),
                    "description": .string("Audio encoding format. Options: mp3, wav, pcm. Default: mp3."),
                    "enum": .array([
                        .string("mp3"),
                        .string("wav"),
                        .string("pcm"),
                    ]),
                ]),
                "sample_rate": .object([
                    "type": .string("integer"),
                    "description": .string("Audio sample rate in Hz. Options: 16000, 24000, 32000, 44100."),
                ]),
                "bitrate": .object([
                    "type": .string("integer"),
                    "description": .string("Audio bitrate in bps. Options: 32000, 64000, 128000, 256000."),
                ]),
                "aigc_watermark": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to add an AIGC watermark at the end of audio. Default: false."),
                ]),
            ]),
        ])
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        kernel: LumiKernel
    ) async throws -> String {
        try kernel.checkCancellation()

        // 1. 解析参数
        let prompt = arguments["prompt"]?.stringValue
        let lyrics = arguments["lyrics"]?.stringValue
        let model = arguments["model"]?.stringValue ?? MiniMaxMusicModel.defaultModel.rawValue
        let isInstrumental = arguments["is_instrumental"]?.boolValue ?? false
        let lyricsOptimizer = arguments["lyrics_optimizer"]?.boolValue ?? false
        let audioUrl = arguments["audio_url"]?.stringValue
        let audioFormat = arguments["audio_format"]?.stringValue
        let sampleRate = intArgument(arguments["sample_rate"])
        let bitrate = intArgument(arguments["bitrate"])
        let aigcWatermark = arguments["aigc_watermark"]?.boolValue ?? false

        // 2. 插入 pending 记录
        let recordID = await recordStore?.insertPendingRecord(
            prompt: prompt,
            lyrics: lyrics,
            model: model,
            isInstrumental: isInstrumental,
            lyricsOptimizer: lyricsOptimizer,
            audioUrl: audioUrl,
            coverFeatureId: nil,
            audioFormat: audioFormat,
            sampleRate: sampleRate,
            bitrate: bitrate,
            aigcWatermark: aigcWatermark
        )

        // 3. 调用 client 生成音乐
        do {
            let asset = try await client.generate(
                prompt: prompt,
                lyrics: lyrics,
                model: model,
                isInstrumental: isInstrumental,
                lyricsOptimizer: lyricsOptimizer,
                audioUrl: audioUrl,
                audioBase64: nil,
                coverFeatureId: nil,
                audioFormat: audioFormat,
                sampleRate: sampleRate,
                bitrate: bitrate,
                aigcWatermark: aigcWatermark
            )

            try kernel.checkCancellation()

            // 4. 标记成功
            if let recordID {
                await recordStore?.markSuccess(
                    recordID: recordID,
                    traceId: asset.traceId,
                    audioURL: asset.audioURL,
                    durationMs: asset.durationMs,
                    channels: asset.channels,
                    fileSize: asset.fileSize
                )
            }

            // 5. 格式化返回结果
            return formatResult(
                asset: asset,
                model: model,
                prompt: prompt,
                lyrics: lyrics,
                isInstrumental: isInstrumental
            )
        } catch is CancellationError {
            if let recordID {
                await recordStore?.markCancelled(recordID: recordID, traceId: nil)
            }
            throw CancellationError()
        } catch let error as MiniMaxMusicError {
            if let recordID {
                await recordStore?.markFailed(recordID: recordID, traceId: nil, errorMessage: error.localizedDescription)
            }
            return formatError(error)
        } catch {
            if let recordID {
                await recordStore?.markFailed(recordID: recordID, traceId: nil, errorMessage: error.localizedDescription)
            }
            return "**Error:** \(error.localizedDescription)"
        }
    }

    // MARK: - Formatters

    private func formatResult(
        asset: MiniMaxMusicGeneratedAsset,
        model: String,
        prompt: String?,
        lyrics: String?,
        isInstrumental: Bool
    ) -> String {
        let urlString = asset.audioURL.absoluteString
        var lines = [
            "## 🎵 Music Generated",
            "",
        ]

        if let prompt {
            lines.append("- **Prompt:** \(prompt)")
        }
        lines.append("- **Model:** \(model)")
        lines.append("- **Instrumental:** \(isInstrumental ? "Yes" : "No")")

        if let durationMs = asset.durationMs {
            let seconds = Double(durationMs) / 1000.0
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            lines.append("- **Duration:** \(minutes):\(String(format: "%02d", secs))")
        }
        if let fileSize = asset.fileSize {
            lines.append("- **File Size:** \(formatByteCount(Int64(fileSize)))")
        }
        if let sampleRate = asset.sampleRate {
            lines.append("- **Sample Rate:** \(sampleRate) Hz")
        }
        if let bitrate = asset.bitrate {
            lines.append("- **Bitrate:** \(bitrate / 1000) kbps")
        }
        if let channels = asset.channels {
            lines.append("- **Channels:** \(channels)")
        }

        lines.append("")
        lines.append("**Download link** (valid for **24 hours**):")
        lines.append("")
        lines.append("> \(urlString)")
        lines.append("")
        lines.append("Click the link above to listen to or download the generated music in your browser.")

        return lines.joined(separator: "\n")
    }

    private func formatError(_ error: MiniMaxMusicError) -> String {
        switch error {
        case .missingAPIKey:
            return "**Error:** MiniMax API Key is not configured. Please add your API key in Lumi settings first."
        default:
            return "**Error:** \(error.localizedDescription)"
        }
    }

    private func formatByteCount(_ byteCount: Int64) -> String {
        if byteCount < 1024 {
            return "\(byteCount) B"
        } else if byteCount < 1024 * 1024 {
            return String(format: "%.1f KB", Double(byteCount) / 1024)
        } else {
            return String(format: "%.1f MB", Double(byteCount) / (1024 * 1024))
        }
    }

    private func intArgument(_ value: LumiJSONValue?) -> Int? {
        switch value {
        case .int(let intValue): return intValue
        case .double(let doubleValue): return Int(doubleValue)
        default: return nil
        }
    }
}
