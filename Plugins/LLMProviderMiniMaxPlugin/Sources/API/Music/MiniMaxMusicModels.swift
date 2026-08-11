import Foundation

struct MiniMaxMusicGenerationRequest: Encodable, Equatable, Sendable {
    let model: String, prompt: String?, lyrics: String?, stream: Bool
    let outputFormat: String?, audioSetting: MiniMaxMusicAudioSetting?
    let aigcWatermark: Bool?, lyricsOptimizer: Bool?, isInstrumental: Bool?
    let audioUrl: String?, audioBase64: String?, coverFeatureId: String?
    enum CodingKeys: String, CodingKey {
        case model, prompt, lyrics, stream
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

struct MiniMaxMusicAudioSetting: Encodable, Equatable, Sendable {
    let sampleRate: Int?, bitrate: Int?, format: String?
    enum CodingKeys: String, CodingKey {
        case sampleRate = "sample_rate"
        case bitrate, format
    }
}

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

struct MiniMaxMusicData: Decodable, Equatable, Sendable {
    let status: Int?
    let audio: String?
}

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
