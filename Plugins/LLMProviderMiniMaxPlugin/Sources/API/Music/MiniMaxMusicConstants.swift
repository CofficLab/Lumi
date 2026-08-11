import Foundation

public enum MiniMaxMusicConstants {
    public static let baseURL: String = "https://api.minimaxi.com"
    public static let musicGenerationPath: String = "/v1/music_generation"
    public static let jsonContentType: String = "application/json"
    public static let audioMimeType: String = "audio/mpeg"
}

public enum MiniMaxMusicModel: String, CaseIterable, Sendable {
    case music30 = "music-3.0"
    case music26 = "music-2.6"
    case musicCover = "music-cover"
    case music30Free = "music-3.0-free"
    case music26Free = "music-2.6-free"
    case musicCoverFree = "music-cover-free"
    public static var defaultModel: MiniMaxMusicModel { .music30Free }
    public var isCoverModel: Bool { self == .musicCover || self == .musicCoverFree }
}

public enum MiniMaxMusicOutputFormat: String, CaseIterable, Sendable {
    case url
    case hex
    public static var defaultFormat: MiniMaxMusicOutputFormat { .url }
}

public enum MiniMaxMusicAudioFormat: String, CaseIterable, Sendable {
    case mp3, wav, pcm
}
