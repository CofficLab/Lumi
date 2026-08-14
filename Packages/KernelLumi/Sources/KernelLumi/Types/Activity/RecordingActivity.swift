import Foundation

// MARK: - Recording Activity

/// 屏幕录制会话的状态变化记录，用于 UI 反馈（浮层指示器等）。
///
/// 由 `ScreenRecorderPlugin` 的 `RecordingSessionManager` 在录制状态变化时发射，
/// 经 `EventManager` 广播，供 UI 层订阅。该类型为纯值类型且 `Sendable`，可安全
/// 从录制线程传递到主线程。结构与 `WebRequestActivity` 对齐。
public struct RecordingActivity: Sendable {
    /// 录制会话状态。
    public enum State: String, Sendable {
        case idle
        case recording
        case stopping
        case finished
        case error
    }

    /// 当前状态。
    public let state: State
    /// 会话 ID（`idle` 时可能为 nil）。
    public let sessionID: UUID?
    /// 录制目标的可读描述（如 "Maps (Apple Maps)"）。
    public let targetDescription: String?
    /// 已录制秒数（仅 `recording`/`stopping`/`finished` 时有意义）。
    public let elapsedSeconds: Int?
    /// 输出文件路径（仅 `finished` 时有意义）。
    public let outputPath: String?
    /// 错误信息（仅 `error` 时有意义）。
    public let error: String?
    /// 状态变化时间。
    public let timestamp: Date

    public init(
        state: State,
        sessionID: UUID? = nil,
        targetDescription: String? = nil,
        elapsedSeconds: Int? = nil,
        outputPath: String? = nil,
        error: String? = nil,
        timestamp: Date = Date()
    ) {
        self.state = state
        self.sessionID = sessionID
        self.targetDescription = targetDescription
        self.elapsedSeconds = elapsedSeconds
        self.outputPath = outputPath
        self.error = error
        self.timestamp = timestamp
    }
}

// MARK: - Notification UserInfo

/// `recordingStateChanged` 事件的 userInfo 键命名空间。
public enum RecordingActivityNotification {
    /// 携带 `RecordingActivity` 的 userInfo 键。
    public static let activityKey = "RecordingActivity"
}

public extension Notification {
    /// 取出 `.lumiRecordingStateChanged` 通知携带的活动记录。
    var lumiRecordingActivity: RecordingActivity? {
        userInfo?[RecordingActivityNotification.activityKey] as? RecordingActivity
    }
}
