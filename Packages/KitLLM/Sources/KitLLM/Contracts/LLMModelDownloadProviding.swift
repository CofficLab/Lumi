import Combine
import Foundation

/// 模型下载任务的状态。
public enum LLMModelDownloadStatus: Equatable, Sendable {
    case idle
    case downloading
    case paused
    case completed
    case failed(String)
}

/// 模型下载进度。
public struct LLMModelDownloadProgress: Equatable, Sendable {
    public var fractionCompleted: Double
    public var completedFiles: Int
    public var totalFiles: Int
    public var downloadedBytes: Int64
    public var totalBytes: Int64
    public var speedBytesPerSecond: Double?

    public init(
        fractionCompleted: Double = 0,
        completedFiles: Int = 0,
        totalFiles: Int = 0,
        downloadedBytes: Int64 = 0,
        totalBytes: Int64 = 0,
        speedBytesPerSecond: Double? = nil
    ) {
        self.fractionCompleted = fractionCompleted
        self.completedFiles = completedFiles
        self.totalFiles = totalFiles
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.speedBytesPerSecond = speedBytesPerSecond
    }
}

/// 供应商模型下载的可观察状态快照。
public struct LLMModelDownloadState: Equatable, Sendable {
    public var status: LLMModelDownloadStatus
    public var modelID: String?
    public var progress: LLMModelDownloadProgress
    public var currentFileName: String?
    public var downloadedModelIDs: Set<String>
    public var cacheSizeBytes: Int64
    public var speedLimitBytesPerSecond: Int?

    public init(
        status: LLMModelDownloadStatus = .idle,
        modelID: String? = nil,
        progress: LLMModelDownloadProgress = .init(),
        currentFileName: String? = nil,
        downloadedModelIDs: Set<String> = [],
        cacheSizeBytes: Int64 = 0,
        speedLimitBytesPerSecond: Int? = nil
    ) {
        self.status = status
        self.modelID = modelID
        self.progress = progress
        self.currentFileName = currentFileName
        self.downloadedModelIDs = downloadedModelIDs
        self.cacheSizeBytes = cacheSizeBytes
        self.speedLimitBytesPerSecond = speedLimitBytesPerSecond
    }
}

/// LLM 供应商可选的模型下载能力。
///
/// 推理供应商无需实现此协议；支持本地模型下载的供应商按需实现即可。
@MainActor
public protocol LLMModelDownloadProviding: AnyObject {
    /// 当前下载状态快照。
    var downloadState: LLMModelDownloadState { get }

    /// 状态变化流，供 UI 实时刷新进度和按钮状态。
    var downloadStatePublisher: AnyPublisher<LLMModelDownloadState, Never> { get }

    /// 模型缓存目录，供设置页提供“打开目录”操作。
    var modelCacheDirectoryURL: URL { get }

    func download(modelID: String) async
    func pauseDownload()
    func resumeDownload() async
    func cancelDownload()
    func deleteDownloadedModel(modelID: String) throws
    func setDownloadSpeedLimit(bytesPerSecond: Int?)
    func refreshDownloadState()
}
