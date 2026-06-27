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
        /// 下载速率限制（字节/秒）。`nil` 表示不限速
        public var maxBytesPerSecond: Int?

        public init(
            downloadDirectory: URL? = nil,
            maxConcurrentDownloads: Int = 3,
            timeoutInterval: TimeInterval = 3600,
            enableResume: Bool = true,
            maxBytesPerSecond: Int? = nil
        ) {
            self.downloadDirectory = downloadDirectory ?? URL.temporaryDirectory.appendingPathComponent("DownloadKit")
            self.maxConcurrentDownloads = maxConcurrentDownloads
            self.timeoutInterval = timeoutInterval
            self.enableResume = enableResume
            self.maxBytesPerSecond = maxBytesPerSecond
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let httpClient: HTTPClient
    private let fileValidator: FileValidator
    private let resumeHandler: ResumeHandler
    private let fileManager = FileManager.default

    /// 共享限速器。
    ///
    /// 仅当内部使用默认 `DefaultHTTPClient` 时被注入（见 init），由所有下载复用，
    /// 使 `setMaxBytesPerSecond(_:)` 的运行时调整能即时作用于正在进行的下载。
    /// 用户注入自定义 HTTPClient 时为 nil，退回每次下载按 `maxBytesPerSecond` 限速的旧行为。
    private let rateLimiter: RateLimiter?

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

        // 用户未提供 HTTPClient 时，创建带共享限速器的 DefaultHTTPClient，
        // 使运行时 setMaxBytesPerSecond 能即时生效（下载到一半改限速）。
        if let httpClient {
            self.httpClient = httpClient
            self.rateLimiter = nil
        } else {
            let limiter = RateLimiter(bytesPerSecond: configuration.maxBytesPerSecond)
            self.rateLimiter = limiter
            self.httpClient = DefaultHTTPClient(rateLimiter: limiter)
        }

        self.fileValidator = FileValidator()
        self.resumeHandler = ResumeHandler()

        // 不在初始化时创建下载目录：否则仅实例化 DownloadManager（如插件启动时
        // 触发的懒加载）就会在用户磁盘上空建一个目录。真正发起下载时
        // `performDownload` 会为目标目录调用 createDirectory，按需创建即可。
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

    /// 获取所有任务状态
    /// - Returns: 所有任务 ID 到状态的映射
    public func allTaskStates() -> [String: DownloadTaskState] {
        return taskStates
    }

    /// 运行时更新下载速率限制（字节/秒）。`nil` 表示不限速。
    ///
    /// 需配合内部共享限速器（默认 `DefaultHTTPClient`）使用：调用后正在进行的下载
    /// 会在下一次令牌补充时按新值限速，无需重启任务。用户注入了自定义 HTTPClient 时
    /// 此方法不生效（返回 false），限速应由该 client 自行处理。
    @discardableResult
    public func setMaxBytesPerSecond(_ maxBytesPerSecond: Int?) -> Bool {
        guard let rateLimiter else { return false }
        rateLimiter.update(bytesPerSecond: maxBytesPerSecond)
        return true
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

            // 计算断点续传起点：读目标文件已存在的字节数（部分文件）。
            // 字节级续传以「磁盘上已下载字节数」为续传点，不再依赖 URLSession 的 resume data blob。
            let existingBytes: Int64 = {
                guard configuration.enableResume,
                      let attrs = try? fileManager.attributesOfItem(atPath: task.destination.path),
                      let size = attrs[.size] as? Int64 else {
                    return 0
                }
                return size
            }()

            // 执行下载（流式追加写入，常驻内存恒定）
            let progressStartTime = Date()
            let taskId = task.id
            // 捕获用户进度回调为局部 Sendable 引用：HTTPClient 的 progressHandler 在后台线程
            // 同步执行，这里直接同步投递给用户，避免经 actor 异步派发（updateStateAndNotify）
            // 时，下载快速完成导致状态先变 final、滞后的中间进度回调被吞掉。
            let userProgressHandler = progressHandlers[taskId]

            _ = try await httpClient.download(
                from: task.url,
                to: task.destination,
                existingBytes: existingBytes,
                maxBytesPerSecond: configuration.maxBytesPerSecond,
                progressHandler: { [weak self] downloadedBytes, totalBytes in
                    let elapsed = Date().timeIntervalSince(progressStartTime)
                    // speed 以「本次新下载字节」计，避免续传时把 existingBytes 计入速率导致偏低
                    let newBytes = max(0, downloadedBytes - existingBytes)
                    let speed = elapsed > 0 ? Double(newBytes) / elapsed : nil

                    let progress = DownloadProgress(
                        downloadedBytes: downloadedBytes,
                        totalBytes: totalBytes,
                        downloadedFiles: 0,
                        totalFiles: 1,
                        bytesPerSecond: speed
                    )
                    // 同步投递给用户（可靠，不受 actor 调度时序影响）
                    userProgressHandler?(progress)
                    // 异步更新内部状态。若任务已被取消/完成，updateStateAndNotify 内部会
                    // 跳过覆盖（见下方实现），避免滞后的进度回调把 .cancelled 改回
                    // .downloading，从而让取消后重新下载同 id 被误判为「已在进行中」。
                    Task { [weak self] in
                        await self?.updateStateAndNotify(taskId, progress)
                    }
                },
                onCancelled: { _ in
                    // 流式写入已即时落盘，取消时磁盘上的部分文件即为下次续传的起点，
                    // 无需 resume data blob。回调保留以满足协议契约。
                }
            )

            // 验证文件
            _ = try fileValidator.validate(fileAt: task.destination, expectedSize: task.expectedSize)

            // 投递最终进度（100%）：下载完成时同步补发一次，确保订阅者能收到完成态进度，
            // 即便中间回调因时序未全部送达。
            if let finalHandler = userProgressHandler {
                let finalProgress = DownloadProgress(
                    downloadedBytes: task.expectedSize ?? 0,
                    totalBytes: task.expectedSize,
                    downloadedFiles: 1,
                    totalFiles: 1,
                    bytesPerSecond: nil
                )
                finalHandler(finalProgress)
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
        // 若任务已被取消/失败/完成（终态），不再被滞后的进度回调覆盖回 .downloading。
        // 这是取消（暂停）后能重新下载同一文件的关键：否则残留的 .downloading 状态会让
        // 下一次 download() 的前置检查误抛「任务已在进行中」。
        if let existing = taskStates[taskId], existing.isFinal {
            return
        }
        taskStates[taskId] = .downloading(progress: progress)
        progressHandlers[taskId]?(progress)
    }
}
