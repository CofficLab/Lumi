import Foundation

public struct RecordingActivity: Sendable {
    public enum State: String, Sendable { case idle, recording, stopping, finished, error }
    public let state: State
    public let sessionID: UUID?
    public let outputPath: String?
    public let error: String?
    public let targetDescription: String?
    public let elapsedSeconds: Int
    public init(state: State, sessionID: UUID?, targetDescription: String? = nil, elapsedSeconds: Int = 0, outputPath: String? = nil, error: String? = nil) { self.state = state; self.sessionID = sessionID; self.targetDescription = targetDescription; self.elapsedSeconds = elapsedSeconds; self.outputPath = outputPath; self.error = error }
}
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
    /// 分辨率高度上限：异常的大整数会在像素换算时溢出 `Int`。
    static let maxResolutionHeight = 4320
    /// 单次录制时长上限（秒），与工具 schema 保持一致。
    static let maxDurationLimit = 3600

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
        self.resolutionHeight = resolutionHeight.map { max(1, min(Self.maxResolutionHeight, $0)) }
        self.includeAppAudio = includeAppAudio
        self.includeMicrophone = includeMicrophone
        self.showCursor = showCursor
        self.maxDurationSeconds = maxDurationSeconds.map { max(1, min(Self.maxDurationLimit, $0)) }
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
    case microphoneUnsupported
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
        case .microphoneUnsupported:
            "Microphone capture requires macOS 15 or later. Retry with include_microphone set to false, or record on macOS 15+ to capture your voice."
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

// MARK: - Microphone capability

/// 麦克风采集能力判定。
///
/// `SCStreamConfiguration.captureMicrophone` 与 `.microphone` 输出都自 macOS 15 起提供。
/// macOS 14 上继续录制只会得到「开始/保存都成功、但完全没有声音」的视频，
/// 因此必须在请求权限和创建文件之前明确拒绝，不能静默降级。
enum RecordingMicrophoneCapability {
    /// SCStream 麦克风采集所需的最低系统主版本号。
    static let minimumMajorVersion = 15

    static var currentMajorVersion: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    static func isSupported(majorVersion: Int) -> Bool {
        majorVersion >= minimumMajorVersion
    }

    /// 请求了麦克风但系统不支持时抛出 `.microphoneUnsupported`。
    static func validate(
        includeMicrophone: Bool,
        majorVersion: Int = currentMajorVersion
    ) throws {
        guard includeMicrophone, !isSupported(majorVersion: majorVersion) else { return }
        throw RecordingError.microphoneUnsupported
    }
}
