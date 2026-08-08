import Foundation

// MARK: - MiniMaxVideoConstants

public enum MiniMaxVideoConstants {
    public static let baseURL: String = "https://api.minimaxi.com"
    public static let createTaskPath: String = "/v1/video_generation"
    public static let queryTaskPath: String = "/v1/query/video_generation"
    public static let retrieveFilePath: String = "/v1/files/retrieve"
    public static let pollInterval: UInt64 = 5_000_000_000
    public static let maxPollingDuration: TimeInterval = 180
    public static let jsonContentType: String = "application/json"
    public static let videoMimeType: String = "video/mp4"
}

public enum MiniMaxVideoModel: String, CaseIterable, Sendable {
    case hailuo23 = "MiniMax-Hailuo-2.3"
    case hailuo02 = "Hailuo-02"
    case t2v01Director = "T2V-01-Director"
    case t2v01 = "T2V-01"
    public static var defaultModel: MiniMaxVideoModel { .hailuo23 }
}

public enum MiniMaxVideoDuration: Int, CaseIterable, Sendable {
    case sixSeconds = 6
    case tenSeconds = 10
    public static var defaultDuration: MiniMaxVideoDuration { .sixSeconds }
}

public enum MiniMaxVideoResolution: String, CaseIterable, Sendable {
    case sd720p = "720P"
    case sd768p = "768P"
    case hd1080p = "1080P"
    public static var defaultResolution: MiniMaxVideoResolution { .sd768p }
}

public enum MiniMaxVideoTaskStatus: String, Sendable {
    case queue = "Queue"
    case preparing = "Preparing"
    case processing = "Processing"
    case success = "Success"
    case fail = "Fail"
    public var isTerminal: Bool { self == .success || self == .fail }
}
