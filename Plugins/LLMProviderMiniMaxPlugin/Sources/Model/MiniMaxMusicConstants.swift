import Foundation

// MARK: - MiniMaxMusicConstants

/// MiniMax 音乐生成 API 常量集合。
///
/// 集中管理端点 URL、模型枚举等硬编码值，避免散落在业务代码中。
public enum MiniMaxMusicConstants {
    // MARK: - Endpoints

    /// MiniMax 音乐生成服务的基础 URL。
    public static let baseURL: String = "https://api.minimaxi.com"

    /// 音乐生成端点（POST /v1/music_generation）。
    public static let musicGenerationPath: String = "/v1/music_generation"

    // MARK: - Content Types

    public static let jsonContentType: String = "application/json"
    public static let audioMimeType: String = "audio/mpeg"
}

// MARK: - MiniMaxMusicModel

/// MiniMax 音乐生成支持的模型枚举。
///
/// 分为两大类：
/// - **文本生成音乐**：music-3.0, music-2.6, music-3.0-free, music-2.6-free
/// - **翻唱**：music-cover, music-cover-free
///
/// `-free` 后缀为限免版本，所有用户可使用，RPM 为 3。
public enum MiniMaxMusicModel: String, CaseIterable, Sendable {
    /// 最新推荐模型（文本生成音乐）。
    case music30 = "music-3.0"

    /// 上一代文本生成音乐模型。
    case music26 = "music-2.6"

    /// 翻唱模型（基于参考音频生成翻唱版本）。
    case musicCover = "music-cover"

    /// music-3.0 的限免版本，所有用户可通过 API Key 使用，RPM 为 3。
    case music30Free = "music-3.0-free"

    /// music-2.6 的限免版本，所有用户可通过 API Key 使用，RPM 为 3。
    case music26Free = "music-2.6-free"

    /// music-cover 的限免版本，所有用户可通过 API Key 使用，RPM 为 3。
    case musicCoverFree = "music-cover-free"

    /// 默认模型。
    public static var defaultModel: MiniMaxMusicModel { .music30Free }

    /// 是否为翻唱模型。
    public var isCoverModel: Bool {
        self == .musicCover || self == .musicCoverFree
    }
}

// MARK: - MiniMaxMusicOutputFormat

/// 音乐生成的输出格式。
public enum MiniMaxMusicOutputFormat: String, CaseIterable, Sendable {
    /// 返回下载 URL（24 小时有效）。
    case url
    /// 返回 hex 编码的音频数据。
    case hex

    /// 默认格式（url，适合 Agent 工具返回链接）。
    public static var defaultFormat: MiniMaxMusicOutputFormat { .url }
}

// MARK: - MiniMaxMusicAudioFormat

/// 音频编码格式。
public enum MiniMaxMusicAudioFormat: String, CaseIterable, Sendable {
    case mp3
    case wav
    case pcm
}

// MARK: - MiniMaxMusicRecordStatus

/// 音乐生成记录的本地状态枚举。
enum MiniMaxMusicRecordStatus: String, Sendable {
    /// 任务已提交，等待 API 响应。
    case pending
    /// 生成成功，已获取音频 URL。
    case success
    /// 生成失败。
    case failed
    /// 用户取消。
    case cancelled
}
