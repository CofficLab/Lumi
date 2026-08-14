import Foundation
import KernelLumi

// MARK: - Recording Target

/// 录制目标。
public enum RecordingTarget: Sendable, Equatable {
    /// 录制某个 app 的窗口。
    case appWindow(application: String, windowTitle: String?)
    /// 录制整个显示器（默认排除 Lumi 自身窗口）。
    case display(excludeLumi: Bool = true)
}

// MARK: - Recording Config

/// 一次录制会话的配置（由工具在 `execute` 内解析并校验后传入会话管理器）。
public struct RecordingConfig: Sendable {
    public let sessionID: UUID
    public let target: RecordingTarget
    public var frameRate: Int
    public var resolutionHeight: Int?
    public var includeAppAudio: Bool
    public var includeMicrophone: Bool
    public var showCursor: Bool
    public var maxDurationSeconds: Int?
    /// 已校验的输出目录（绝对路径）。
    public var outputDirectory: URL
    public var filename: String?

    public init(
        sessionID: UUID = UUID(),
        target: RecordingTarget,
        frameRate: Int = 30,
        resolutionHeight: Int? = nil,
        includeAppAudio: Bool = false,
        includeMicrophone: Bool = false,
        showCursor: Bool = true,
        maxDurationSeconds: Int? = nil,
        outputDirectory: URL,
        filename: String? = nil
    ) {
        self.sessionID = sessionID
        self.target = target
        self.frameRate = max(1, min(60, frameRate))
        self.resolutionHeight = resolutionHeight
        self.includeAppAudio = includeAppAudio
        self.includeMicrophone = includeMicrophone
        self.showCursor = showCursor
        self.maxDurationSeconds = maxDurationSeconds
        self.outputDirectory = outputDirectory
        self.filename = filename
    }
}

// MARK: - Recording Session

/// 当前录制会话的运行时快照（由 `RecordingSessionManager` 在主线程上维护）。
public struct RecordingSession: Sendable {
    public let id: UUID
    public let config: RecordingConfig
    public var state: RecordingActivity.State
    public let startedAt: Date
    /// 已解析的目标可读描述（如 "Maps" / "Apple Display"）。
    public var targetDescription: String
    public var outputURL: URL?
    public var error: String?

    public var isActive: Bool {
        switch state {
        case .recording, .stopping: true
        case .idle, .finished, .error: false
        }
    }

    public init(
        id: UUID = UUID(),
        config: RecordingConfig,
        state: RecordingActivity.State = .idle,
        startedAt: Date = Date(),
        targetDescription: String = "",
        outputURL: URL? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.config = config
        self.state = state
        self.startedAt = startedAt
        self.targetDescription = targetDescription
        self.outputURL = outputURL
        self.error = error
    }
}

// MARK: - Recording Result

/// 一次录制结束后的结果摘要。
public struct RecordingResult: Sendable {
    public let outputURL: URL
    public let durationSeconds: Int
    public let fileSizeBytes: Int64
    public let width: Int
    public let height: Int

    public init(outputURL: URL, durationSeconds: Int, fileSizeBytes: Int64, width: Int, height: Int) {
        self.outputURL = outputURL
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.width = width
        self.height = height
    }
}

// MARK: - Recording Error

/// 录制流程中可向用户/LLM 友好呈现的错误。
public enum RecordingError: LocalizedError, Sendable {
    case permissionDenied
    case microphonePermissionDenied
    case noSuchWindow(String)
    case targetIsLumi
    case alreadyRecording(String)
    case notRecording
    case encodingFailed(String)
    case diskFull
    case pathDenied(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Screen Recording permission is required. Please grant it in System Settings."
        case .microphonePermissionDenied:
            "Microphone permission is required to record your voice. Please grant it in System Settings."
        case .noSuchWindow(let app):
            "No visible window found for “\(app)”. Is the app running?"
        case .targetIsLumi:
            "Refused to record Lumi itself."
        case .alreadyRecording(let desc):
            "A recording is already in progress (\(desc)). Stop it first."
        case .notRecording:
            "There is no recording in progress."
        case .encodingFailed(let detail):
            "Failed to encode the recording: \(detail)"
        case .diskFull:
            "Not enough disk space to save the recording."
        case .pathDenied(let path):
            "The path “\(path)” is outside the allowed directories."
        case .cancelled:
            "The recording was cancelled."
        }
    }
}
