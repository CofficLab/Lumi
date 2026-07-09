import Foundation
import SuperLogKit
import Combine
import DownloadKit
import os

// Forward reference to MLXModels
private typealias _MLXModels = MLXModels

/// MLX 下载管理器
///
/// 负责从 HuggingFace 下载 MLX 模型文件。
/// 特性：
/// - 断点续传支持
/// - 下载进度实时回调
/// - 文件验证（safetensors 非空检查）
/// - 使用 DownloadKit 提供的健壮下载基础设施
///
/// 使用 Combine 发布事件，UI 可以订阅变化。
@MainActor
public final class MLXDownloadManager: NSObject, ObservableObject, SuperLog {
    nonisolated public static let emoji = "⬇️"
    nonisolated public static let verbose: Bool = true

    /// 全局共享的下载管理器单例
    ///
    /// 使用单例确保下载任务独立于视图生命周期，
    /// 即使视图关闭也能在后台继续下载，重新打开时恢复进度。
    public static let shared = MLXDownloadManager()

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.mlx")

    // MARK: - Published Properties

    /// 下载状态
    @Published public private(set) var status: MLXDownloadStatus = .idle

    /// 下载进度
    @Published public private(set) var progress: MLXDownloadProgress = .init()

    /// 正在下载的模型 ID
    @Published public private(set) var downloadingModelId: String?

    /// 当前正在下载的文件名
    @Published public private(set) var currentFileName: String?

    /// 当前正在下载的文件大小（字节）
    @Published public private(set) var currentFileSize: Int64 = 0

    /// 当前文件已下载的字节数
    @Published public private(set) var currentFileDownloadedBytes: Int64 = 0

    // MARK: - Private Properties

    private var downloadTask: Task<Void, Never>?
    private var isShutdown = false

    /// 标记当前取消是「暂停」意图还是「真取消」。
    ///
    /// `downloadTask` 被取消后，其 `catch` 分支会在 MainActor 上异步执行；若不区分意图，
    /// 暂停（`status = .paused`）会被取消分支无脑改回 `.idle`，导致暂停实际等于取消、
    /// 恢复按钮永不出现。置 true 时，取消分支须保留 `.paused` 状态。
    private var isPauseRequested = false

    /// 追踪 `cancelAll()` 的执行，避免与新下载产生竞态。
    ///
    /// `pause()`/`cancel()` 是同步方法（UI 直接调用），无法 `await` `cancelAll()`；
    /// 若用 fire-and-forget `Task`，紧随其后的 `download()`/`resume()` 发起的新下载可能被
    /// 尚未跑完的 `cancelAll()` 误杀。这里把取消任务保存下来，在发起新下载前先 await 它。
    private var downloadKitCancellation: Task<Void, Never>?

    private let fileManager = FileManager.default
    private let downloadManager: DownloadManager

    /// 下载限速设置的 UserDefaults key（字节/秒，0 表示不限速）。
    ///
    /// 单独定义为常量，便于 UI（MLXLocalProviderSettingsView 的 @AppStorage）与
    /// 本管理器读写同一 key，避免字符串散落不一致。标记 nonisolated 以允许从
    /// `nonisolated` 的 `currentSpeedLimitBytes()` 中引用。
    nonisolated static let downloadSpeedLimitKey = "mlx.download.maxBytesPerSecond"

    /// 当前下载限速（字节/秒）。`nil` 表示不限速。
    ///
    /// 值来源于 UserDefaults[key]：0 或缺失视为不限速。调用 `updateDownloadSpeed`
    /// 会同时更新本字段与底层 DownloadKit 限速器（即时作用于进行中的下载）。
    @Published public private(set) var downloadSpeedLimit: Int?

    // MARK: - Pause/Resume State

    private var pausedModelId: String?
    private var pausedProgress: MLXDownloadProgress?

    /// 恢复下载时的进度地板（fraction 下限）。
    ///
    /// 暂停时正在下载的文件会被重新下载，其已下载部分字节不再计入新的 `downloadedBytes`，
    /// 导致恢复瞬间 fraction 从「含部分字节」跌到「仅完整文件」，进度条先跌后涨。
    /// 记录暂停时刻的 fraction 作为地板：恢复后任何重算的 fraction 不低于它，
    /// 进度条保持暂停值，直到真实下载进度自然超过它。设为 nil 表示无地板（首次下载）。
    private var resumeFloorFraction: Double?

    // MARK: - Initialization

    private override init() {
        let initialLimit = MLXDownloadManager.readSpeedLimit()
        let config = DownloadManager.Configuration(
            downloadDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("lumi-mlx-download"),
            maxConcurrentDownloads: 3,
            timeoutInterval: 3600,
            enableResume: true,
            maxBytesPerSecond: initialLimit
        )
        self.downloadManager = DownloadManager(configuration: config)

        super.init()

        // @Published 属性需在 super.init 之后赋值；此处与传入 DownloadManager 的值保持一致。
        downloadSpeedLimit = initialLimit

        try? fileManager.createDirectory(at: config.downloadDirectory, withIntermediateDirectories: true)

        if Self.verbose {
            Self.logger.info("\(self.t)MLXDownloadManager 已初始化，限速：\(String(describing: self.downloadSpeedLimit))")
        }
    }

    deinit {
        downloadTask?.cancel()
        // 释放未等待的 DownloadKit 取消任务，避免悬挂
        downloadKitCancellation?.cancel()
    }

    // MARK: - Public Methods

    /// 下载模型
    public func download(modelId: String) async {
        guard !isShutdown else {
            Self.logger.warning("\(self.t)下载被拒绝：管理器已关闭")
            return
        }

        let isAlreadyDownloading = downloadingModelId == modelId && status == .downloading
        if isAlreadyDownloading {
            Self.logger.info("\(self.t)跳过重复下载：\(modelId)")
            return
        }

        cancel(resetPublishedState: false)

        // 发起新下载前，先确保上一次 pause/cancel 触发的 cancelAll() 已落地，
        // 否则新下载可能被尚未跑完的取消任务误杀。
        await awaitDownloadKitCancellation()

        downloadingModelId = modelId
        status = .downloading
        progress = MLXDownloadProgress()
        // 全新下载无暂停历史，清除可能残留的恢复地板
        resumeFloorFraction = nil

        Self.logger.info("\(self.t)🟢 开始下载模型：\(modelId)")

        let task = Task { [weak self] in
            guard let self else {
                Self.logger.warning("\(Self.t)下载任务中 self 已释放")
                return
            }

            do {
                let localDir = _MLXModels.cacheDirectory(for: modelId)
                Self.logger.info("\(self.t)下载目标目录：\(localDir.path)")

                try await self.downloadAllFiles(modelId: modelId, to: localDir)

                if Task.isCancelled {
                    // 暂停意图：保留 .paused，由 pause() 维护的状态接管；否则复位为 idle。
                    if self.isPauseRequested {
                        Self.logger.info("\(self.t)下载已暂停：\(modelId)")
                    } else {
                        Self.logger.info("\(self.t)下载任务被取消：\(modelId)")
                        self.status = .idle
                        self.downloadingModelId = nil
                    }
                    return
                }

                self.status = .completed
                self.downloadingModelId = nil
                Self.logger.info("\(self.t)✅ 模型下载完成：\(modelId)")

            } catch {
                if !Task.isCancelled {
                    self.status = .failed(error.localizedDescription)
                    self.downloadingModelId = nil
                    Self.logger.error("\(self.t)❌ 模型下载失败：\(modelId)\n错误详情：\(error.localizedDescription)")
                } else if self.isPauseRequested {
                    // 暂停：下载在文件传输中途被取消并抛错，保留 .paused 等待恢复。
                    Self.logger.info("\(self.t)下载已暂停（异常路径）：\(modelId)")
                } else {
                    Self.logger.info("\(self.t)下载任务被取消（异常路径）：\(modelId)")
                    self.status = .idle
                    self.downloadingModelId = nil
                }
            }
        }

        downloadTask = task
        await task.value
    }

    /// 取消下载
    public func cancel() {
        cancel(resetPublishedState: true)
    }

    /// 更新下载限速（字节/秒）。`nil` 表示不限速。
    ///
    /// 同时写回 UserDefaults（供下次启动恢复）并同步到底层 DownloadKit 限速器，
    /// 使设置即时作用于正在进行的下载（下载到一半改限速无需暂停/恢复）。
    /// - Parameter bytesPerSecond: 目标限速；`nil` 解除限速。
    public func updateDownloadSpeed(bytesPerSecond: Int?) {
        downloadSpeedLimit = bytesPerSecond
        UserDefaults.standard.set(bytesPerSecond ?? 0, forKey: Self.downloadSpeedLimitKey)
        let dm = downloadManager
        Task { await dm.setMaxBytesPerSecond(bytesPerSecond) }
        Self.logger.info("\(self.t)🎚️ 下载限速已更新为：\(bytesPerSecond.map { "\($0) 字节/秒" } ?? "不限速")")
    }

    /// 从 UserDefaults 读取限速设置。0 或缺失返回 nil（不限速）。
    private static func readSpeedLimit() -> Int? {
        let value = UserDefaults.standard.object(forKey: downloadSpeedLimitKey) as? Int ?? 0
        return value > 0 ? value : nil
    }

    /// 当前限速值（字节/秒），不限速时返回 0。供 UI Picker 作为当前选中项。
    ///
    /// 直接从 UserDefaults 读取（而非 `downloadSpeedLimit` 发布属性），使该方法可
    /// `nonisolated` 调用——UI 的 `@State` 初始化发生在 `MLXDownloadManager`
    /// 主 actor 之外，避免跨 actor 访问 `@Published` 属性。
    nonisolated public func currentSpeedLimitBytes() -> Int {
        let value = UserDefaults.standard.object(forKey: Self.downloadSpeedLimitKey) as? Int ?? 0
        return value > 0 ? value : 0
    }

    /// 暂停下载
    public func pause() {
        guard status == .downloading, let modelId = downloadingModelId else {
            Self.logger.warning("\(self.t)无法暂停：当前未在下载")
            return
        }

        Self.logger.info("\(self.t)⏸️ 暂停下载：\(modelId)")

        // 标记为暂停意图：取消分支据此保留 .paused，避免被改回 .idle（暂停≠取消）
        isPauseRequested = true

        // 保存当前状态，供 resume() 续传
        pausedModelId = modelId
        // 清除实时速率后快照：暂停后不再有新字节流入，保留 speed 会让 UI 显示陈旧值
        progress.speed = nil
        pausedProgress = progress

        // 设置状态为暂停
        status = .paused

        // 取消当前下载任务（但不重置状态）
        downloadTask?.cancel()
        downloadTask = nil

        // 取消 DownloadKit 中的任务（被追踪，发起新下载前会 await）
        cancelDownloadKit()
    }

    /// 恢复下载
    public func resume() async {
        guard status == .paused, let modelId = pausedModelId else {
            Self.logger.warning("\(self.t)无法恢复：当前未暂停")
            return
        }

        Self.logger.info("\(self.t)▶️ 恢复下载：\(modelId)")

        // 已不再是暂停意图
        isPauseRequested = false

        // 恢复状态
        downloadingModelId = modelId
        status = .downloading

        if let savedProgress = pausedProgress {
            progress = savedProgress
            // 记录暂停时刻的 fraction 作为恢复地板：暂停时正在下载文件的部分字节
            // 会在恢复后重下时丢失，重算 fraction 会因此下跌。地板保证恢复后进度条
            // 不回退，停留在暂停值直到真实进度超过它。
            resumeFloorFraction = savedProgress.fractionCompleted
        }

        // 清除暂停状态
        pausedModelId = nil
        pausedProgress = nil

        // 发起新下载前，先确保暂停时触发的 cancelAll() 已落地，避免误杀恢复任务
        await awaitDownloadKitCancellation()

        // 重新启动下载
        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let localDir = _MLXModels.cacheDirectory(for: modelId)
                let startIndex = Int(self.progress.completedFiles)

                try await self.downloadAllFiles(modelId: modelId, to: localDir, startIndex: startIndex)

                if Task.isCancelled {
                    // 恢复期间再次暂停：保留 .paused；真取消则复位
                    if self.isPauseRequested {
                        Self.logger.info("\(self.t)恢复后再次暂停：\(modelId)")
                    } else {
                        self.status = .idle
                        self.downloadingModelId = nil
                    }
                    return
                }

                self.status = .completed
                self.downloadingModelId = nil
                self.resumeFloorFraction = nil
                Self.logger.info("\(self.t)✅ 模型下载完成：\(modelId)")

            } catch {
                if !Task.isCancelled {
                    self.status = .failed(error.localizedDescription)
                    self.downloadingModelId = nil
                    self.resumeFloorFraction = nil
                    Self.logger.error("\(self.t)❌ 模型下载失败：\(modelId) - \(error.localizedDescription)")
                } else if self.isPauseRequested {
                    // 恢复期间被暂停（异常路径）：保留 .paused 等待再次恢复
                    Self.logger.info("\(self.t)恢复后再次暂停（异常路径）：\(modelId)")
                } else {
                    self.status = .idle
                    self.downloadingModelId = nil
                }
            }
        }

        downloadTask = task
        await task.value
    }

    private func cancel(resetPublishedState shouldResetPublishedState: Bool) {
        // 真取消：清除暂停意图
        isPauseRequested = false

        downloadTask?.cancel()
        downloadTask = nil

        // 取消 DownloadKit 中的所有任务（被追踪，发起新下载前会 await）
        cancelDownloadKit()

        if shouldResetPublishedState {
            resetPublishedState()
        }

        if Self.verbose {
            Self.logger.info("\(self.t)下载已取消")
        }
    }

    public func shutdown() {
        guard !isShutdown else { return }
        isShutdown = true

        // 真取消：清除暂停意图
        isPauseRequested = false

        downloadTask?.cancel()
        downloadTask = nil

        cancelDownloadKit()

        resetPublishedState()
    }

    /// 重置状态
    public func reset() {
        cancel()
    }

    // MARK: - DownloadKit Cancellation Helpers

    /// 异步取消 DownloadKit 中所有任务，并追踪该任务以便后续 await。
    ///
    /// `pause()`/`cancel()` 是同步方法，无法 `await` `cancelAll()`，但若不等待，
    /// 紧随其后的 `download()`/`resume()` 发起新下载会被误杀。这里把取消任务保存下来，
    /// 供 `awaitDownloadKitCancellation()` 在发起新下载前等待。
    private func cancelDownloadKit() {
        let dm = downloadManager
        downloadKitCancellation = Task { await dm.cancelAll() }
    }

    /// 等待上一次 `cancelDownloadKit()` 完成，确保新下载不会被陈旧的取消误杀。
    private func awaitDownloadKitCancellation() async {
        if let task = downloadKitCancellation {
            await task.value
            downloadKitCancellation = nil
        }
    }

    // MARK: - Download Pipeline

    private func downloadAllFiles(modelId: String, to localDir: URL, startIndex: Int = 0) async throws {
        Self.logger.info("\(self.t)获取文件列表：\(modelId)")
        let files = try await fetchFileList(modelId: modelId)
        Self.logger.info("\(self.t)原始文件数量：\(files.count)")

        let filteredFiles = Self.filterFiles(files)
        Self.logger.info("\(self.t)过滤后文件数量：\(filteredFiles.count)")

        guard !filteredFiles.isEmpty else {
            Self.logger.error("\(self.t)❌ 没有可下载的文件")
            throw MLXDownloadError.noFilesAvailable
        }

        let totalBytes = filteredFiles.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
        Self.logger.info("\(self.t)总下载大小：\(totalBytes) 字节")

        updateProgress(totalFiles: Int64(filteredFiles.count), totalBytes: totalBytes)

        try fileManager.createDirectory(at: localDir, withIntermediateDirectories: true)
        Self.logger.info("\(self.t)下载目录已创建：\(localDir.path)")

        var downloadedBytes: Int64 = 0
        let dm = downloadManager

        // 如果从中间开始（恢复场景）：只更新 completedFiles/totalFiles，
        // fractionCompleted 保留 resume() 里恢复的暂停值（savedProgress.fractionCompleted）。
        // 绝不能用「仅完整文件字节」去重算 fraction——暂停时正在下载文件的部分字节
        // 已计入暂停值，但这里只累加完整文件，重算会让 fraction 跌到（只含完整文件的比例），
        // 进度条先跌到接近 0、再随该文件重下爬回，视觉上像「变成 0」。
        // downloadedBytes 局部变量仍正确累加完整文件字节，供后续进度回调
        // `downloadedBytes + newBytes`（与正常下载一致的推进方式）。
        if startIndex > 0 {
            for index in 0..<startIndex {
                let file = filteredFiles[index]
                downloadedBytes += file.size ?? 0
            }
            updateProgress(
                completedFiles: Int64(startIndex),
                totalFiles: Int64(filteredFiles.count),
                totalBytes: totalBytes
            )
            Self.logger.info("\(self.t)▶️ 从第 \(startIndex) 个文件继续下载")
        }

        for (index, file) in filteredFiles.enumerated() {
            try Task.checkCancellation()

            // 跳过已完成的文件
            if index < startIndex {
                continue
            }

            let fileURL = localDir.appendingPathComponent(file.path)
            let parentDir = fileURL.deletingLastPathComponent()
            if parentDir != localDir {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            let expectedSize = file.size ?? 0

            // 检查已存在的本地文件，决定是跳过、续传还是全新下载。
            // existingSize 用于续传起点：部分文件（暂停时下载了一部分）保留不删，
            // 交给 DownloadKit 用 HTTP Range 从断点继续——这正是「不重头下载、不浪费」的关键。
            var fileResumeBytes: Int64 = 0
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let existingSize = attrs[.size] as? Int64 {
                if existingSize == expectedSize, expectedSize > 0 {
                    Self.logger.info("\(self.t)⏭️ 文件已存在，跳过：\(file.path) (size=\(existingSize))")
                    downloadedBytes += expectedSize
                    updateProgress(completedFiles: Int64(index + 1), downloadedBytes: downloadedBytes, totalBytes: totalBytes)
                    continue
                } else if expectedSize > 0, existingSize > 0, existingSize < expectedSize {
                    // 部分文件：保留，作为字节级续传起点（DownloadKit 会发 Range 请求继续）
                    fileResumeBytes = existingSize
                    Self.logger.info("\(self.t)⏏️ 续传文件：\(file.path) (已下载 \(existingSize)/\(expectedSize) 字节)")
                }
            }

            // 使用 DownloadKit 下载文件
            let encodedPath = file.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file.path
            let urlString = "https://huggingface.co/\(modelId)/resolve/main/\(encodedPath)"
            guard let url = URL(string: urlString) else {
                Self.logger.error("\(self.t)❌ 无效的 URL：\(urlString)")
                throw MLXDownloadError.invalidURL
            }

            Self.logger.info("\(self.t)📥 下载文件 [\(index + 1)/\(filteredFiles.count)]：\(file.path) (\(expectedSize) 字节)")

            // 更新当前下载的文件名和大小；已下载字节从续传起点初始化，进度条不回退到 0
            currentFileName = file.path
            currentFileSize = expectedSize
            currentFileDownloadedBytes = fileResumeBytes

            let task = DownloadTask(
                id: file.path,
                url: url,
                destination: fileURL,
                expectedSize: expectedSize
            )

            do {
                // 下载进度回调是 @Sendable，会在非 MainActor 的并发上下文执行；
                // 若直接捕获外层 var downloadedBytes 再传给内部 @MainActor Task，
                // Swift 6 会判定该变量跨越 actor 边界存在数据竞争。
                // 这里先取不可变快照，闭包只捕获 Sendable 的 let，规避竞争。
                let baseDownloadedBytes = downloadedBytes
                _ = try await dm.download(task) { [weak self] progress in
                    let newBytes = progress.downloadedBytes
                    let speed = progress.bytesPerSecond
                    Task { @MainActor in
                        guard let self else { return }
                        // 只在新值大于当前值时更新，避免并发 Task 调度乱序导致进度回退显示
                        if newBytes > self.currentFileDownloadedBytes {
                            self.currentFileDownloadedBytes = newBytes
                            // 将当前文件的实时字节数纳入整体进度，避免进度条在大文件下载期间冻结
                            self.updateProgress(
                                downloadedBytes: baseDownloadedBytes + newBytes,
                                totalBytes: totalBytes,
                                speed: speed
                            )
                        }
                    }
                }
                downloadedBytes += expectedSize
                updateProgress(completedFiles: Int64(index + 1), downloadedBytes: downloadedBytes, totalBytes: totalBytes)
                Self.logger.info("\(self.t)✅ 文件下载完成：\(file.path)")
            } catch {
                Self.logger.error("\(self.t)❌ 文件下载失败：\(file.path)\n错误：\(error.localizedDescription)")
                // 转换 DownloadKit 错误为 MLX 错误
                if let downloadError = error as? DownloadKit.DownloadError {
                    switch downloadError {
                    case .sizeMismatch(let expected, let actual):
                        throw MLXDownloadError.sizeMismatch(expected, actual)
                    case .emptyFile:
                        throw MLXDownloadError.emptySafetensorsFile(file.path)
                    default:
                        throw MLXDownloadError.downloadFailed(error.localizedDescription)
                    }
                } else {
                    throw MLXDownloadError.downloadFailed(error.localizedDescription)
                }
            }
        }

        // 验证 safetensors
        Self.logger.info("\(self.t)开始验证 safetensors 文件")
        for file in filteredFiles where file.path.hasSuffix(".safetensors") {
            let fileURL = localDir.appendingPathComponent(file.path)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                Self.logger.error("\(self.t)❌ 缺失 safetensors 文件：\(file.path)")
                throw MLXDownloadError.missingFile(file.path)
            }
            let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
            let size = attrs[.size] as? Int64 ?? 0
            if size == 0 {
                Self.logger.error("\(self.t)❌ safetensors 文件为空：\(file.path)")
                throw MLXDownloadError.emptySafetensorsFile(file.path)
            }
            Self.logger.info("\(self.t)✅ safetensors 验证通过：\(file.path) (\(size) 字节)")
        }

        // 验证加载模型必需的配置文件（swift-transformers 硬性要求 tokenizer.json 存在）
        let requiredConfigFiles = ["tokenizer.json", "config.json"]
        for fileName in requiredConfigFiles {
            // 仅验证 filterFiles 已包含的文件：如果原始文件列表中没有该文件则跳过
            guard filteredFiles.contains(where: { $0.path.components(separatedBy: "/").last == fileName }) else {
                continue
            }
            let fileURL = localDir.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                Self.logger.error("\(self.t)❌ 缺失必需配置文件：\(fileName)")
                throw MLXDownloadError.missingFile(fileName)
            }
            let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
            let size = attrs[.size] as? Int64 ?? 0
            if size == 0 {
                Self.logger.error("\(self.t)❌ 必需配置文件为空：\(fileName)")
                throw MLXDownloadError.emptySafetensorsFile(fileName)
            }
            Self.logger.info("\(self.t)✅ 配置文件验证通过：\(fileName) (\(size) 字节)")
        }
        Self.logger.info("\(self.t)所有文件下载和验证完成")
    }

    private func fetchFileList(modelId: String) async throws -> [HFFileEntry] {
        let urlString = "https://huggingface.co/api/models/\(modelId)/tree/main"
        Self.logger.info("\(self.t)获取文件列表 URL：\(urlString)")

        guard let url = URL(string: urlString) else {
            Self.logger.error("\(self.t)❌ 无效的文件列表 URL")
            throw MLXDownloadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                Self.logger.info("\(self.t)文件列表 HTTP 状态码：\(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw MLXDownloadError.httpError(httpResponse.statusCode)
                }
            }

            Self.logger.info("\(self.t)文件列表响应大小：\(data.count) 字节")

            do {
                let entries = try JSONDecoder().decode([HFFileEntry].self, from: data)
                Self.logger.info("\(self.t)解析到 \(entries.count) 个条目")

                var allFiles = entries.filter { $0.type == "file" }
                Self.logger.info("\(self.t)根目录文件数：\(allFiles.count)")

                let directories = entries.filter({ $0.type == "directory" })
                Self.logger.info("\(self.t)子目录数：\(directories.count)")

                for dir in directories {
                    Self.logger.info("\(self.t)扫描子目录：\(dir.path)")
                    let subFiles = try await fetchSubdirectory(modelId: modelId, path: dir.path)
                    Self.logger.info("\(self.t)子目录 \(dir.path) 文件数：\(subFiles.count)")
                    allFiles.append(contentsOf: subFiles)
                }

                Self.logger.info("\(self.t)总计文件数：\(allFiles.count)")
                return allFiles

            } catch let decodingError {
                Self.logger.error("\(self.t)❌ JSON 解析失败：\(decodingError.localizedDescription)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    Self.logger.error("\(self.t)响应内容前 500 字符：\(String(jsonString.prefix(500)))")
                }
                throw MLXDownloadError.invalidResponse
            }

        } catch let urlError as URLError {
            Self.logger.error("\(self.t)❌ 网络错误：\(urlError.localizedDescription)\n错误码：\(urlError.code.rawValue)")
            throw MLXDownloadError.downloadFailed("网络错误：\(urlError.localizedDescription)")
        }
    }

    private func fetchSubdirectory(modelId: String, path: String) async throws -> [HFFileEntry] {
        let urlString = "https://huggingface.co/api/models/\(modelId)/tree/main/\(path)"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        let entries = try JSONDecoder().decode([HFFileEntry].self, from: data)
        var files = entries.filter { $0.type == "file" }

        for subdir in entries.filter({ $0.type == "directory" }) {
            let subFiles = try await fetchSubdirectory(modelId: modelId, path: subdir.path)
            files.append(contentsOf: subFiles)
        }

        return files
    }

    /// 过滤 HuggingFace 文件列表，保留模型所需的文件
    ///
    /// 规则：
    /// - 排除 README/LICENSE/.git/onnx/flax/tf/pytorch 等无关文件
    /// - 保留 safetensors/json/txt/py/tiktoken 等模型必需文件
    /// - 保留按文件名匹配的必需配置文件
    ///
    /// 设为 `nonisolated` 以便在任意上下文（含单元测试）中直接调用，
    /// 因为过滤逻辑是纯函数，不依赖任何 MainActor 实例状态。
    nonisolated static func filterFiles(_ files: [HFFileEntry]) -> [HFFileEntry] {
        let requiredExts: Set<String> = [".safetensors", ".json", ".txt", ".py", ".tiktoken"]
        let requiredNames: Set<String> = ["config.json", "tokenizer.json", "tokenizer_config.json",
                                          "generation_config.json", "special_tokens_map.json", "chat_template.jinja"]
        let exclude: [String] = ["README.md", "LICENSE", ".git", "onnx/", "flax_", "tf_", "pytorch_"]

        return files.filter { file in
            let name = file.path.components(separatedBy: "/").last ?? ""
            let lower = file.path.lowercased()

            if exclude.contains(where: { lower.contains($0.lowercased()) }) { return false }
            if requiredNames.contains(name) { return true }
            if requiredExts.contains(where: { name.hasSuffix($0) }) { return true }
            return false
        }
    }

    // MARK: - Status Updates

    private func updateProgress(completedFiles: Int64? = nil, downloadedBytes: Int64? = nil,
                                totalFiles: Int64? = nil, totalBytes: Int64? = nil,
                                speed: Double? = nil) {
        if let cf = completedFiles { progress.completedFiles = cf }
        if let tf = totalFiles { progress.totalFiles = tf }
        // 速度即时刷新：DownloadKit 回调给出的 bytesPerSecond 直接反映当前文件实时速率，
        // 每次回调都覆盖，避免停留陈旧值（回调频率高，无需额外平滑）。
        if let speed { progress.speed = speed }
        if let db = downloadedBytes, let tb = totalBytes {
            var fraction = Self.downloadProgressFraction(
                writtenBytes: db,
                totalBytes: tb
            )
            // 恢复场景的地板：重算的 fraction 不应低于暂停时刻的值。
            // 暂停时正在下载文件的部分字节在恢复后会因重下而短暂缺失，
            // 没有地板的话进度条会先跌到「仅完整文件」比例，视觉上像变成 0。
            if let floor = resumeFloorFraction, fraction < floor {
                fraction = floor
            }
            progress.fractionCompleted = fraction
        }
    }

    static func downloadProgressFraction(writtenBytes: Int64, totalBytes: Int64, maxFraction: Double = 0.95) -> Double {
        guard totalBytes > 0, writtenBytes >= 0, maxFraction.isFinite, maxFraction > 0 else {
            return 0
        }

        let fraction = Double(writtenBytes) / Double(totalBytes) * maxFraction
        guard fraction.isFinite else { return 0 }
        return min(max(fraction, 0), maxFraction)
    }

    private func resetPublishedState() {
        status = .idle
        downloadingModelId = nil
        currentFileName = nil
        currentFileSize = 0
        progress = MLXDownloadProgress()
        // 复位时一并清除恢复地板，避免残留到下次下载
        resumeFloorFraction = nil
    }
}

// MARK: - Supporting Types

public enum MLXDownloadStatus: Equatable, Sendable {
    case idle, downloading, paused, completed, failed(String), cancelling

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.downloading, .downloading), (.paused, .paused),
             (.completed, .completed), (.cancelling, .cancelling): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

public struct MLXDownloadProgress: Sendable {
    public var fractionCompleted: Double = 0
    public var completedFiles: Int64 = 0
    public var totalFiles: Int64 = 0
    public var speed: Double? = nil

    public var speedLabel: String {
        guard let speed, speed > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }

    public var percentLabel: String { "\(Int(fractionCompleted * 100))%" }
    public init() {}
}

/// HuggingFace 文件树条目（对应 HF API 返回的文件信息）
///
/// 设为 `internal` 以便单元测试构造 `filterFiles` 的输入数据。
struct HFFileEntry: Decodable {
    let type: String
    let path: String
    let size: Int64?

    init(type: String, path: String, size: Int64? = nil) {
        self.type = type
        self.path = path
        self.size = size
    }
}

public enum MLXDownloadError: LocalizedError {
    case invalidURL, invalidResponse, httpError(Int), noFilesAvailable
    case missingFile(String), emptySafetensorsFile(String), sizeMismatch(Int64, Int64)
    case downloadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .invalidResponse: return "无效的响应"
        case .httpError(let code): return "HTTP 错误：\(code)"
        case .noFilesAvailable: return "没有可下载的文件"
        case .missingFile(let path): return "缺失文件：\(path)"
        case .emptySafetensorsFile(let path): return "空文件：\(path)"
        case .sizeMismatch(let exp, let act): return "大小不匹配：期望 \(exp), 实际 \(act)"
        case .downloadFailed(let msg): return "下载失败：\(msg)"
        }
    }
}
