import Foundation

// MARK: - MiniMaxVideoConstants

/// MiniMax 视频生成 API 常量集合。
///
/// 集中管理端点 URL、模型枚举、轮询节奏等硬编码值，避免散落在业务代码中。
public enum MiniMaxVideoConstants {
    // MARK: - Endpoints

    /// MiniMax 视频生成服务的基础 URL。
    public static let baseURL: String = "https://api.minimaxi.com"

    /// Step 1: 提交视频生成任务。
    public static let createTaskPath: String = "/v1/video_generation"

    /// Step 2: 查询任务状态。
    public static let queryTaskPath: String = "/v1/query/video_generation"

    /// Step 3: 获取文件下载链接。
    public static let retrieveFilePath: String = "/v1/files/retrieve"

    // MARK: - Polling

    /// 单次轮询间隔（秒）。MiniMax 文档建议 5–10 秒。
    public static let pollInterval: UInt64 = 5_000_000_000

    /// 单次轮询超时上限（秒）。视频生成通常 30 秒–2 分钟，2 分钟未成功视作失败。
    public static let maxPollingDuration: TimeInterval = 180

    // MARK: - Content Types

    public static let jsonContentType: String = "application/json"
    public static let videoMimeType: String = "video/mp4"
}

// MARK: - MiniMaxVideoModel

/// MiniMax 视频生成支持的模型枚举。
///
/// 与官方文档对齐：新模型（`Hailuo-*`）和旧模型（`T2V-01-*`）在参数支持范围上略有差异，
/// 工具接受字符串以兼容未来新增模型，但这里集中列出已知可用模型作为提示。
public enum MiniMaxVideoModel: String, CaseIterable, Sendable {
    /// 当前推荐模型，支持 1080P / 10s。
    case hailuo23 = "MiniMax-Hailuo-2.3"

    /// 第二代 Hailuo 模型。
    case hailuo02 = "Hailuo-02"

    /// 旧版导演模式（镜头运动控制）。
    case t2v01Director = "T2V-01-Director"

    /// 旧版标准模型。
    case t2v01 = "T2V-01"

    /// 默认模型。
    public static var defaultModel: MiniMaxVideoModel { .hailuo23 }
}

// MARK: - MiniMaxVideoDuration

/// MiniMax 视频生成支持的时长（秒）。
public enum MiniMaxVideoDuration: Int, CaseIterable, Sendable {
    case sixSeconds = 6
    case tenSeconds = 10

    /// 默认 6 秒（所有模型通用且成本较低）。
    public static var defaultDuration: MiniMaxVideoDuration { .sixSeconds }
}

// MARK: - MiniMaxVideoResolution

/// MiniMax 视频生成支持的分辨率。
///
/// 仅 `MiniMax-Hailuo-2.3` 与 `Hailuo-02` 支持 `1080P`；旧模型仅 `720P` / `768P`。
public enum MiniMaxVideoResolution: String, CaseIterable, Sendable {
    case sd720p = "720P"
    case sd768p = "768P"
    case hd1080p = "1080P"

    /// 默认 768P（在质量/成本/兼容性间折中）。
    public static var defaultResolution: MiniMaxVideoResolution { .sd768p }
}

// MARK: - MiniMaxVideoTaskStatus

/// MiniMax 视频任务状态字符串。
///
/// MiniMax 文档原文："Queue"、"Preparing"、"Processing"、"Success"、"Fail"。
public enum MiniMaxVideoTaskStatus: String, Sendable {
    case queue = "Queue"
    case preparing = "Preparing"
    case processing = "Processing"
    case success = "Success"
    case fail = "Fail"

    public var isTerminal: Bool {
        self == .success || self == .fail
    }
}
