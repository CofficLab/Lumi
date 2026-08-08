import Foundation

// MARK: - MiniMaxImageRecordStatus

/// 图片生成记录的状态枚举。
enum MiniMaxImageRecordStatus: String, Sendable {
    case pending
    case success
    case failed
    case cancelled
}

// MARK: - MiniMaxMusicRecordStatus

/// 音乐生成记录的状态枚举。
enum MiniMaxMusicRecordStatus: String, Sendable {
    case pending
    case success
    case failed
    case cancelled
}
