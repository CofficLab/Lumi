import Foundation
import SwiftData

/// MiniMax 音乐生成记录的持久化模型。
///
/// 由 `MiniMaxMusicRecordStore` 使用 SwiftData 持久化到
/// `storage.pluginDataDirectory(for: "LLMProviderMiniMax")` 下的 SQLite 文件。
///
/// 每条记录对应一次音乐生成请求，从任务提交到最终成功/失败全生命周期。
@Model
final class MiniMaxMusicRecordModel {
    /// 本地唯一标识。
    @Attribute(.unique) var id: String
    /// MiniMax 返回的 trace_id。
    var traceId: String?
    /// 用户输入的音乐描述（风格/情绪/场景）。
    var prompt: String?
    /// 用户输入的歌词。
    var lyrics: String?
    /// 使用的模型名称（如 "music-3.0"）。
    var model: String
    /// 是否纯音乐（无人声）。
    var isInstrumental: Bool
    /// 是否自动生成歌词。
    var lyricsOptimizer: Bool
    /// 翻唱参考音频 URL（仅 music-cover 模型）。
    var audioUrl: String?
    /// 翻唱前处理特征 ID（仅 music-cover 模型）。
    var coverFeatureId: String?
    /// 音频编码格式（mp3/wav/pcm）。
    var audioFormat: String?
    /// 采样率（Hz）。
    var sampleRate: Int?
    /// 比特率（bps）。
    var bitrate: Int?
    /// 是否添加 AIGC 水印。
    var aigcWatermark: Bool
    /// 任务最终状态：pending / success / failed / cancelled。
    var status: String
    /// 生成的音频 URL（24 小时有效）。
    var audioURL: String?
    /// 音频时长（毫秒）。
    var durationMs: Int?
    /// 音频声道数。
    var channels: Int?
    /// 文件大小（字节）。
    var fileSize: Int?
    /// 失败时的错误信息。
    var errorMessage: String?
    /// 记录创建时间（任务提交时刻）。
    var createdAt: Date
    /// 任务完成时间（成功或失败的终态时刻）。
    var completedAt: Date?
    /// 音频 URL 过期时间（createdAt + 24h 近似值）。
    var audioURLExpiresAt: Date?

    init(
        id: String = UUID().uuidString,
        traceId: String? = nil,
        prompt: String? = nil,
        lyrics: String? = nil,
        model: String,
        isInstrumental: Bool = false,
        lyricsOptimizer: Bool = false,
        audioUrl: String? = nil,
        coverFeatureId: String? = nil,
        audioFormat: String? = nil,
        sampleRate: Int? = nil,
        bitrate: Int? = nil,
        aigcWatermark: Bool = false,
        status: String,
        audioURL: String? = nil,
        durationMs: Int? = nil,
        channels: Int? = nil,
        fileSize: Int? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        audioURLExpiresAt: Date? = nil
    ) {
        self.id = id
        self.traceId = traceId
        self.prompt = prompt
        self.lyrics = lyrics
        self.model = model
        self.isInstrumental = isInstrumental
        self.lyricsOptimizer = lyricsOptimizer
        self.audioUrl = audioUrl
        self.coverFeatureId = coverFeatureId
        self.audioFormat = audioFormat
        self.sampleRate = sampleRate
        self.bitrate = bitrate
        self.aigcWatermark = aigcWatermark
        self.status = status
        self.audioURL = audioURL
        self.durationMs = durationMs
        self.channels = channels
        self.fileSize = fileSize
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.audioURLExpiresAt = audioURLExpiresAt
    }
}
