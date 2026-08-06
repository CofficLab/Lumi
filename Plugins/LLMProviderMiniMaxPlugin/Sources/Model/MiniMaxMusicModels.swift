import Foundation

// MARK: - MiniMax Music API DTOs
//
// MiniMax 音乐生成服务（POST /v1/music_generation）的请求/响应模型。
// 所有 DTO 仅在 `Sources/Model/` 和 `Sources/Tools/` 内部使用，不对外暴露。

// MARK: - Request

/// 音乐生成请求体：`POST /v1/music_generation`。
///
/// 字段对齐 MiniMax 官方文档：
/// - `model`: 必填
/// - `prompt`: 音乐描述（风格/情绪/场景）
/// - `lyrics`: 歌词（支持结构标签）
/// - `output_format`: url 或 hex
/// - `audio_setting`: 音频输出配置
/// - `aigc_watermark`: 是否在音频末尾添加水印
/// - `lyrics_optimizer`: 是否自动生成歌词
/// - `is_instrumental`: 是否纯音乐
/// - `audio_url` / `audio_base64`: 翻唱参考音频
/// - `cover_feature_id`: 翻唱前处理特征 ID
struct MiniMaxMusicGenerationRequest: Encodable, Equatable, Sendable {
    let model: String
    let prompt: String?
    let lyrics: String?
    let stream: Bool
    let outputFormat: String?
    let audioSetting: MiniMaxMusicAudioSetting?
    let aigcWatermark: Bool?
    let lyricsOptimizer: Bool?
    let isInstrumental: Bool?
    let audioUrl: String?
    let audioBase64: String?
    let coverFeatureId: String?

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case lyrics
        case stream
        case outputFormat = "output_format"
        case audioSetting = "audio_setting"
        case aigcWatermark = "aigc_watermark"
        case lyricsOptimizer = "lyrics_optimizer"
        case isInstrumental = "is_instrumental"
        case audioUrl = "audio_url"
        case audioBase64 = "audio_base64"
        case coverFeatureId = "cover_feature_id"
    }
}

/// 音频输出配置。
struct MiniMaxMusicAudioSetting: Encodable, Equatable, Sendable {
    let sampleRate: Int?
    let bitrate: Int?
    let format: String?

    enum CodingKeys: String, CodingKey {
        case sampleRate = "sample_rate"
        case bitrate
        case format
    }
}

// MARK: - Response

/// 音乐生成响应：`POST /v1/music_generation`。
///
/// 响应结构：
/// ```json
/// {
///   "data": { "status": 2, "audio": "..." },
///   "extra_info": { "music_duration": 25364, ... },
///   "trace_id": "...",
///   "base_resp": { "status_code": 0, "status_msg": "success" }
/// }
/// ```
struct MiniMaxMusicGenerationResponse: Decodable, Equatable, Sendable {
    let data: MiniMaxMusicData?
    let extraInfo: MiniMaxMusicExtraInfo?
    let traceId: String?
    let baseResp: MiniMaxBaseResp

    enum CodingKeys: String, CodingKey {
        case data
        case extraInfo = "extra_info"
        case traceId = "trace_id"
        case baseResp = "base_resp"
    }
}

/// 响应中的 `data` 字段。
///
/// - `status`: 1 = 合成中，2 = 已完成
/// - `audio`: 当 `output_format` 为 `hex` 时返回 hex 编码字符串；
///   当 `output_format` 为 `url` 时返回音频下载 URL
struct MiniMaxMusicData: Decodable, Equatable, Sendable {
    let status: Int?
    let audio: String?
}

/// 响应中的 `extra_info` 字段，包含音频元数据。
struct MiniMaxMusicExtraInfo: Decodable, Equatable, Sendable {
    let musicDuration: Int?
    let musicSampleRate: Int?
    let musicChannel: Int?
    let bitrate: Int?
    let musicSize: Int?

    enum CodingKeys: String, CodingKey {
        case musicDuration = "music_duration"
        case musicSampleRate = "music_sample_rate"
        case musicChannel = "music_channel"
        case bitrate
        case musicSize = "music_size"
    }
}

// MARK: - Errors

/// 音乐生成流程中可被 UI 区分的错误类型。
enum MiniMaxMusicError: LocalizedError, Equatable {
    /// 未配置 API Key。
    case missingAPIKey
    /// 业务错误：HTTP 200 但 `base_resp.status_code != 0`。
    case apiError(code: Int, message: String)
    /// 响应中无有效音频数据或 URL。
    case noAudioReturned
    /// 工具被取消。
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "MiniMax API Key is not configured. Please add your API key in Lumi settings."
        case .apiError(let code, let message):
            return "MiniMax API error (code=\(code)): \(message)"
        case .noAudioReturned:
            return "MiniMax did not return any audio. The prompt or lyrics may have been blocked by content safety."
        case .cancelled:
            return "MiniMax music generation was cancelled."
        }
    }
}
