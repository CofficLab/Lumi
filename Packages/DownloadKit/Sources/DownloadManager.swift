import Foundation

/// 下载管理器
///
/// 提供健壮的文件下载功能，支持：
/// - 断点续传
/// - 进度追踪
/// - 文件验证
/// - 并发控制
/// - 取消操作
public actor DownloadManager {

    // MARK: - Configuration

    /// 下载配置
    public struct Configuration: Sendable {
        /// 下载目录
        public var downloadDirectory: URL
        /// 最大并发下载数
        public var maxConcurrentDownloads: Int
        /// 超时时间（秒）
        public var timeoutInterval: TimeInterval
        /// 是否启用断点续传
        public var enableResume: Bool

        public init(
            downloadDirectory: URL? = nil,
            maxConcurrentDownloads: Int = 3,
            timeoutInterval: TimeInterval = 3600,
            enableResume: Bool = true
        ) {
            self.downloadDirectory = downloadDirectory ?? URL.temporaryDirectory.appendingPathComponent("DownloadKit")
            self.maxConcurrentDownloads = maxConcurrentDownloads
            self.timeoutInterval = timeoutInterval
            self.enableResume = enableResume
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let httpClient: HTTPClient
    private let fileValidator: FileValidator
    private let resumeHandler: ResumeHandler
    private let fileManager = FileManager.default

    /// 当前活跃任务
    private var activeTasks: [String: Task<Void, Never>] = [:]
    /// 任务状态
    private var taskStates: [String: DownloadTaskState] = [:]
    /// 进度回调
    private var progressHandlers: [String: @Sendable (DownloadProgress) -> Void] = [:]

    // MARK: - Initialization

    public init(
        configuration: Configuration = Configuration(),
        httpClient: HTTPClient? = nil
    ) {
        self.configuration = configuration
        self.httpClient = httpClient ?? DefaultHTTPClient()
        self.fileValidator = FileValidator()
        self.resumeHandler = ResumeHandler()

        // 确保下载目录存在
        try? fileManager.createDirectory(
            at: configuration.downloadDirectory,
            withIntermediateDirectories: true
        )
    }

    deinit {
        for task in activeTasks.values {
            task.cancel()
        }
    }

    // MARK: - Public Methods

    /// 下载文件
    /// - Parameters:
    ///   - task: 下载任务描述
    ///   - progressHandler: 进度回调
    /// - Returns: 下载完成的文件路径
    @discardableResult
    public func download(
        _ task: DownloadTask,
        progressHandler: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        // 检查是否已有相同任务
        if let existingState = taskStates[task.id],
           case .downloading = existingState {
            throw DownloadError.unknown("任务已在进行中: \(task.id)")
        }

        // 记录进度回调
        if let handler = progressHandler {
            progressHandlers[task.id] = handler
        }

        // 创建下载任务
        let downloadTask = Task { [weak self] in
            guard let self else { return }
            await self.performDownload(task)
        }

        activeTasks[task.id] = downloadTask

        // 等待任务完成
        await downloadTask.value

        // 检查结果
        let finalState = taskStates[task.id] ?? .pending
        activeTasks.removeValue(forKey: task.id)
        progressHandlers.removeValue(forKey: task.id)

        switch finalState {
        case .completed:
            return task.destination
        case .failed(let error):
            throw error
        case .cancelled:
            throw DownloadError.cancelled
        default:
            throw DownloadError.unknown("任务状态异常")
        }
    }

    /// 取消下载
    /// - Parameter taskId: 任务 ID
    public func cancel(taskId: String) {
        activeTasks[taskId]?.cancel()
        activeTasks.removeValue(forKey: taskId)
        taskStates[taskId] = .cancelled
        progressHandlers.removeValue(forKey: taskId)
    }

    /// 取消所有下载
    public func cancelAll() {
        for (taskId, task) in activeTasks {
            task.cancel()
            taskStates[taskId] = .cancelled
        }
        activeTasks.removeAll()
        progressHandlers.removeAll()
    }

    /// 获取任务状态
    /// - Parameter taskId: 任务 ID
    /// - Returns: 任务状态
    public func state(for taskId: String) -> DownloadTaskState? {
        return taskStates[taskId]
    }

    // MARK: - Private Methods

    private func performDownload(_ task: DownloadTask) async {
        do {
            // 检查是否已取消
            try Task.checkCancellation()

            // 更新状态为下载中
            updateState(task.id, .downloading(progress: DownloadProgress()))

            // 检查文件是否已完整下载
            if let expectedSize = task.expectedSize,
               fileValidator.isComplete(fileAt: task.destination, expectedSize: expectedSize) {
                updateState(task.id, .completed)
                return
            }

            // 准备目标目录
            let directory = task.destination.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            // 获取断点续传数据
            var resumeData: Data? = nil
            if configuration.enableResume {
                resumeData = await resumeHandler.getResumeData(for: task.destination)
            }

            // 执行下载
            let progressStartTime = Date()
            let taskId = task.id

            _ = try await httpClient.download(
                from: task.url,
                to: task.destination,
                resumeData: resumeData,
                progressHandler: { [weak self] downloadedBytes, totalBytes in
                    guard let self else { return }

                    let elapsed = Date().timeIntervalSince(progressStartTime)
                    let speed = elapsed > 0 ? Double(downloadedBytes) / elapsed : nil

                    let progress = DownloadProgress(
                        downloadedBytes: downloadedBytes,
                        totalBytes: totalBytes,
                        downloadedFiles: 0,
                        totalFiles: 1,
                        bytesPerSecond: speed
                    )

                    Task { [weak self] in
                        await self?.updateStateAndNotify(taskId, progress)
                    }
                }
            )

            // 验证文件
            _ = try fileValidator.validate(fileAt: task.destination, expectedSize: task.expectedSize)

            // 清理断点续传数据
            if configuration.enableResume {
                await resumeHandler.removeResumeData(for: task.destination)
            }

            // 更新状态为完成
            updateState(task.id, .completed)

        } catch is CancellationError {
            updateState(task.id, .cancelled)
        } catch let error as DownloadError {
            updateState(task.id, .failed(error))
        } catch {
            updateState(task.id, .failed(.unknown(error.localizedDescription)))
        }
    }

    private func updateState(_ taskId: String, _ state: DownloadTaskState) {
        taskStates[taskId] = state
    }

    private func updateStateAndNotify(_ taskId: String, _ progress: DownloadProgress) {
        taskStates[taskId] = .downloading(progress: progress)
        progressHandlers[taskId]?(progress)
    }
}
