import Combine
import Foundation
import KitDownload
import KitLLM

@MainActor
public final class MLXDownloadManager: ObservableObject {
    public static let shared = MLXDownloadManager()
    nonisolated public static let downloadSpeedLimitKey = "mlx.download.maxBytesPerSecond"

    @Published public private(set) var status: MLXDownloadStatus = .idle
    @Published public private(set) var progress = MLXDownloadProgress()
    @Published public private(set) var downloadingModelID: String?
    @Published public private(set) var currentFileName: String?
    @Published public private(set) var currentFileSize: Int64 = 0
    @Published public private(set) var currentFileDownloadedBytes: Int64 = 0
    @Published public private(set) var downloadSpeedLimit: Int?

    private let downloadManager: KitDownload.DownloadManager
    private var stateSubject: CurrentValueSubject<LLMModelDownloadState, Never>?
    /// 缓存目录的磁盘扫描结果缓存。
    ///
    /// 进度事件（底层每 64KB 一次）只读缓存，扫描本身只在结构性变化时
    /// 重算，避免把进度回调放大成持续的全目录扫描。
    private let cacheIndex = MLXDownloadCacheIndex()
    private var downloadTask: Task<Void, Never>?
    private var downloadKitCancellation: Task<Void, Never>?
    private var activeOperationID: UUID?
    private var pausedModelID: String?
    private var isPauseRequested = false
    private var isShutdown = false
    private var resumeFloorFraction: Double?

    private init() {
        let initialLimit = Self.readSpeedLimit()
        downloadSpeedLimit = initialLimit
        downloadManager = KitDownload.DownloadManager(configuration: .init(
            downloadDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("lumi-mlx-download"),
            maxConcurrentDownloads: 1,
            timeoutInterval: 3600,
            enableResume: true,
            maxBytesPerSecond: initialLimit
        ))
    }

    public var downloadState: LLMModelDownloadState {
        makeDownloadState()
    }

    /// 已完成的磁盘扫描次数。
    ///
    /// 诊断与回归测试用：下载进度事件不应让它增长——进度只更新字节数与
    /// 比例，不触发全目录扫描。
    var cacheScanCount: Int {
        cacheIndex.scanCount
    }

    /// 作废缓存扫描结果，下次读取时重新扫描磁盘。
    func invalidateCacheSnapshot() {
        cacheIndex.invalidate()
    }

    public var downloadStatePublisher: AnyPublisher<LLMModelDownloadState, Never> {
        if stateSubject == nil {
            stateSubject = CurrentValueSubject(downloadState)
        }
        return stateSubject!.eraseToAnyPublisher()
    }

    public var modelCacheDirectoryURL: URL {
        MLXModelPaths.modelsDirectory
    }

    public func deleteDownloadedModel(modelID: String) throws {
        let directory = MLXModelPaths.modelDirectory(for: modelID)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
        cacheIndex.invalidate()
        refreshDownloadState()
    }

    /// 显式刷新下载状态：磁盘可能已被外部改动，重算缓存扫描结果。
    public func refreshDownloadState() {
        cacheIndex.invalidate()
        stateSubject?.send(downloadState)
    }

    public func configure(rootDirectory: URL) {
        isShutdown = false
        MLXModelPaths.configure(rootDirectory: rootDirectory)
        // 模型根目录变了：此前的扫描结果指向旧目录，必须作废。
        cacheIndex.invalidate()
    }

    public func download(modelID: String) async {
        guard !isShutdown else { return }
        guard MLXProviderCatalog.registrations.contains(where: { $0.id == modelID }) else {
            status = .failed(MLXDownloadError.invalidModelID(modelID).localizedDescription)
            refreshDownloadState()
            return
        }
        if downloadingModelID == modelID, status == .downloading {
            if let task = downloadTask {
                await task.value
            }
            return
        }

        cancel(resetPublishedState: false)
        await awaitDownloadKitCancellation()

        let operationID = UUID()
        activeOperationID = operationID
        isPauseRequested = false
        pausedModelID = nil
        resumeFloorFraction = nil
        downloadingModelID = modelID
        status = .downloading
        progress = MLXDownloadProgress()
        refreshDownloadState()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runDownload(modelID: modelID, operationID: operationID)
        }
        downloadTask = task
        await task.value
    }

    public func pause() {
        guard status == .downloading, let modelID = downloadingModelID else { return }
        isPauseRequested = true
        pausedModelID = modelID
        resumeFloorFraction = progress.fractionCompleted
        progress.speed = nil
        status = .paused
        downloadTask?.cancel()
        downloadTask = nil
        cancelDownloadKit()
        refreshDownloadState()
    }

    public func resume() async {
        guard status == .paused, let modelID = pausedModelID else { return }
        let operationID = UUID()
        activeOperationID = operationID
        isPauseRequested = false
        downloadingModelID = modelID
        status = .downloading
        refreshDownloadState()
        await awaitDownloadKitCancellation()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runDownload(modelID: modelID, operationID: operationID)
        }
        downloadTask = task
        await task.value
    }

    public func cancel() {
        cancel(resetPublishedState: true)
    }

    public func shutdown() {
        guard !isShutdown else { return }
        isShutdown = true
        cancel(resetPublishedState: true)
    }

    public func updateDownloadSpeed(bytesPerSecond: Int?) {
        downloadSpeedLimit = bytesPerSecond
        MLXProviderPluginLocalStore.shared.setDownloadSpeedLimit(bytesPerSecond)
        let manager = downloadManager
        Task { await manager.setMaxBytesPerSecond(bytesPerSecond) }
        refreshDownloadState()
    }

    nonisolated public func currentSpeedLimitBytes() -> Int {
        return max(0, MLXProviderPluginLocalStore.shared.downloadSpeedLimit ?? 0)
    }

    private func runDownload(modelID: String, operationID: UUID) async {
        do {
            let files = try await fetchFiles(modelID: modelID)
            guard !files.isEmpty else { throw MLXDownloadError.noFilesAvailable }
            guard files.contains(where: { $0.path == "config.json" }),
                  files.contains(where: { $0.path == "tokenizer.json" }) else {
                throw MLXDownloadError.missingRequiredFiles
            }

            let modelDirectory = MLXModelPaths.modelDirectory(for: modelID)
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            let totalBytes = files.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
            progress.totalFiles = files.count
            progress.totalBytes = totalBytes
            progress.completedFiles = 0
            progress.downloadedBytes = 0

            var completedBytes: Int64 = 0
            var completedFiles = 0
            for file in files {
                try Task.checkCancellation()
                guard activeOperationID == operationID else { return }

                let destination = destinationURL(for: file.path, in: modelDirectory)
                let localSize = fileSize(at: destination)
                if let expectedSize = file.size, localSize == expectedSize {
                    completedBytes += expectedSize
                    completedFiles += 1
                    publishProgress(
                        operationID: operationID,
                        completedBytes: completedBytes,
                        currentBytes: 0,
                        completedFiles: completedFiles,
                        totalFiles: files.count,
                        totalBytes: totalBytes,
                        speed: nil
                    )
                    continue
                }

                currentFileName = file.path
                currentFileSize = file.size ?? 0
                currentFileDownloadedBytes = max(0, localSize)
                let task = KitDownload.DownloadTask(
                    id: "mlx-\(modelID)-\(file.path)",
                    url: fileURL(modelID: modelID, path: file.path),
                    destination: destination,
                    expectedSize: file.size
                )
                let completedBytesBeforeCurrentFile = completedBytes
                let completedFilesBeforeCurrentFile = completedFiles

                do {
                    _ = try await downloadManager.download(task) { [weak self] fileProgress in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.currentFileDownloadedBytes = fileProgress.downloadedBytes
                            self.publishProgress(
                                operationID: operationID,
                                completedBytes: completedBytesBeforeCurrentFile,
                                currentBytes: fileProgress.downloadedBytes,
                                completedFiles: completedFilesBeforeCurrentFile,
                                totalFiles: files.count,
                                totalBytes: totalBytes,
                                speed: fileProgress.bytesPerSecond
                            )
                        }
                    }
                } catch {
                    throw error
                }

                let finalSize = fileSize(at: destination)
                if let expectedSize = file.size, finalSize != expectedSize {
                    throw MLXDownloadError.incompleteFile(file.path)
                }
                completedBytes += file.size ?? finalSize
                completedFiles += 1
                publishProgress(
                    operationID: operationID,
                    completedBytes: completedBytes,
                    currentBytes: 0,
                    completedFiles: completedFiles,
                    totalFiles: files.count,
                    totalBytes: totalBytes,
                    speed: nil
                )
            }

            try MLXModelDownloader.markComplete(directory: modelDirectory)
            // 模型已落盘：缓存内容变了，下一次状态求值必须重新扫描。
            cacheIndex.invalidate()
            guard activeOperationID == operationID, !Task.isCancelled else { return }
            progress.fractionCompleted = 1
            progress.downloadedBytes = max(progress.downloadedBytes, totalBytes)
            progress.completedFiles = files.count
            progress.speed = nil
            status = .completed
            downloadingModelID = nil
            pausedModelID = nil
            resumeFloorFraction = nil
            activeOperationID = nil
            currentFileName = nil
            currentFileSize = 0
            currentFileDownloadedBytes = 0
            refreshDownloadState()
        } catch {
            guard activeOperationID == operationID else { return }
            if isPauseRequested {
                status = .paused
                pausedModelID = modelID
                return
            }
            if status == .idle || isShutdown { return }
            status = .failed(error.localizedDescription)
            downloadingModelID = nil
            activeOperationID = nil
            currentFileName = nil
            currentFileSize = 0
            currentFileDownloadedBytes = 0
            resumeFloorFraction = nil
            refreshDownloadState()
        }
    }

    private func fetchFiles(modelID: String) async throws -> [MLXHFFileEntry] {
        let parts = modelID.split(separator: "/").map(String.init)
        guard parts.count == 2 else { throw MLXDownloadError.invalidModelID(modelID) }
        let owner = parts[0].addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? parts[0]
        let name = parts[1].addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? parts[1]
        let url = URL(string: "https://huggingface.co/api/models/\(owner)/\(name)/tree/main?recursive=true")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw MLXDownloadError.invalidResponse }
        guard http.statusCode == 200 else { throw MLXDownloadError.httpError(http.statusCode) }
        let entries = try JSONDecoder().decode([MLXHFFileEntry].self, from: data)
        return entries
            .filter { $0.type == "file" && isRequiredFile($0.path) }
            .sorted { $0.path < $1.path }
    }

    private func fileURL(modelID: String, path: String) -> URL {
        let parts = modelID.split(separator: "/").map(String.init)
        let owner = parts[0].addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? parts[0]
        let name = parts[1].addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? parts[1]
        let encodedPath = path.split(separator: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        return URL(string: "https://huggingface.co/\(owner)/\(name)/resolve/main/\(encodedPath)?download=true")!
    }

    private func destinationURL(for path: String, in directory: URL) -> URL {
        path.split(separator: "/").reduce(directory) { url, component in
            url.appendingPathComponent(String(component), isDirectory: false)
        }
    }

    private func isRequiredFile(_ path: String) -> Bool {
        let lower = path.lowercased()
        let filename = lower.split(separator: "/").last.map(String.init) ?? lower
        if ["readme.md", "license"].contains(filename) || lower.contains("/.git/") {
            return false
        }
        if ["onnx/", "flax_", "tf_", "pytorch_"].contains(where: { lower.contains($0) }) {
            return false
        }
        return [".safetensors", ".json", ".txt", ".py", ".jinja", ".model", ".tiktoken"]
            .contains(where: { filename.hasSuffix($0) })
    }

    private func publishProgress(
        operationID: UUID,
        completedBytes: Int64,
        currentBytes: Int64,
        completedFiles: Int,
        totalFiles: Int,
        totalBytes: Int64,
        speed: Double?
    ) {
        guard activeOperationID == operationID else { return }
        progress.completedFiles = completedFiles
        progress.totalFiles = totalFiles
        progress.downloadedBytes = min(totalBytes, max(0, completedBytes + currentBytes))
        progress.totalBytes = totalBytes
        progress.speed = speed
        let calculated = totalBytes > 0
            ? min(0.95, Double(progress.downloadedBytes) / Double(totalBytes) * 0.95)
            : (totalFiles > 0 ? Double(completedFiles) / Double(totalFiles) : 0)
        progress.fractionCompleted = max(resumeFloorFraction ?? 0, calculated)
        refreshDownloadState()
    }

    private func makeDownloadState() -> LLMModelDownloadState {
        // 磁盘扫描结果走缓存索引：进度事件（底层每 64KB 一次）只读缓存，
        // 扫描本身只在结构性变化时重算。
        let cache = cacheIndex.snapshot { scanDownloadCache() }
        return LLMModelDownloadState(
            status: mapStatus(status),
            modelID: downloadingModelID,
            progress: LLMModelDownloadProgress(
                fractionCompleted: progress.fractionCompleted,
                completedFiles: progress.completedFiles,
                totalFiles: progress.totalFiles,
                downloadedBytes: progress.downloadedBytes,
                totalBytes: progress.totalBytes,
                speedBytesPerSecond: progress.speed
            ),
            currentFileName: currentFileName,
            downloadedModelIDs: cache.downloadedModelIDs,
            cacheSizeBytes: cache.cacheSizeBytes,
            speedLimitBytesPerSecond: downloadSpeedLimit
        )
    }

    /// 扫描下载缓存：逐模型检查完成标记 + 递归统计缓存目录大小。
    ///
    /// 这是全量磁盘操作，只在结构性变化后被调用一次。
    private func scanDownloadCache() -> MLXDownloadCacheIndex.Snapshot {
        cacheScanner()
    }

    /// 缓存扫描实现。
    ///
    /// 默认走真实的磁盘扫描；测试可替换为计数桩，断言进度事件不会触发扫描。
    var cacheScanner: () -> MLXDownloadCacheIndex.Snapshot = {
        MLXDownloadCacheIndex.Snapshot(
            downloadedModelIDs: Set(MLXProviderCatalog.availableRegistrations.compactMap { model in
                MLXModelDownloader.isComplete(directory: MLXModelPaths.modelDirectory(for: model.id))
                    ? model.id
                    : nil
            }),
            cacheSizeBytes: MLXDownloadManager.currentCacheSizeBytes(in: MLXModelPaths.modelsDirectory)
        )
    }

    private func mapStatus(_ status: MLXDownloadStatus) -> LLMModelDownloadStatus {
        switch status {
        case .idle: return .idle
        case .downloading: return .downloading
        case .paused: return .paused
        case .completed: return .completed
        case .failed(let message): return .failed(message)
        }
    }

    private var downloadedModelIDs: Set<String> {
        Set(MLXProviderCatalog.availableRegistrations.compactMap { model in
            MLXModelDownloader.isComplete(directory: MLXModelPaths.modelDirectory(for: model.id)) ? model.id : nil
        })
    }

    /// 递归统计缓存目录的总字节数。
    ///
    /// 这是全量磁盘操作：只应在结构性变化后被调用一次（见 ``cacheIndex``）。
    private static func currentCacheSizeBytes(in directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return enumerator.reduce(into: Int64(0)) { total, item in
            guard let url = item as? URL,
                  let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                  values.isDirectory != true else { return }
            total += Int64(values.fileSize ?? 0)
        }
    }

    private func fileSize(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true else { return 0 }
        return Int64(values.fileSize ?? 0)
    }

    private func cancel(resetPublishedState: Bool) {
        isPauseRequested = false
        pausedModelID = nil
        activeOperationID = nil
        downloadTask?.cancel()
        downloadTask = nil
        cancelDownloadKit()
        if resetPublishedState {
            status = .idle
            downloadingModelID = nil
            currentFileName = nil
            currentFileSize = 0
            currentFileDownloadedBytes = 0
            progress = MLXDownloadProgress()
            resumeFloorFraction = nil
            refreshDownloadState()
        }
    }

    private func cancelDownloadKit() {
        let manager = downloadManager
        downloadKitCancellation = Task { await manager.cancelAll() }
    }

    private func awaitDownloadKitCancellation() async {
        if let cancellation = downloadKitCancellation {
            await cancellation.value
            downloadKitCancellation = nil
        }
    }

    private static func readSpeedLimit() -> Int? {
        MLXProviderPluginLocalStore.shared.downloadSpeedLimit
    }
}
