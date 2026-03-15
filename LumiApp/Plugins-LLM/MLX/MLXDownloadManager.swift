import Foundation
import OSLog
import Combine

// Forward reference to MLXModels
private typealias _MLXModels = MLXModels

/// MLX 下载管理器
///
/// 负责从 HuggingFace 下载 MLX 模型文件。
/// 特性：
/// - 断点续传支持
/// - 下载进度实时回调
/// - 文件验证（safetensors 非空检查）
///
/// 使用 Combine 发布事件，UI 可以订阅变化。
public final class MLXDownloadManager: NSObject, ObservableObject {

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "MLXDownloadManager")

    // MARK: - Published Properties

    /// 下载状态
    @Published public private(set) var status: DownloadStatus = .idle

    /// 下载进度
    @Published public private(set) var progress: DownloadProgress = .init()

    /// 正在下载的模型 ID
    @Published public private(set) var downloadingModelId: String?

    // MARK: - Private Properties

    private var downloadTask: Task<Void, Never>?
    private var activeDownloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession!
    private var currentFileProgress: Int64 = 0
    private var currentFileTotal: Int64 = 0

    private let fileManager = FileManager.default
    private var tempDirectory: URL
    private var resumeOffset: Int64 = 0

    // MARK: - Initialization

    public override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600
        self.tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("lumi-mlx-download")

        super.init()

        self.downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        Self.logger.info("MLXDownloadManager 已初始化")
    }

    // MARK: - Public Methods

    /// 下载模型
    public func download(modelId: String) async {
        if self.downloadingModelId == modelId && status == .downloading {
            return
        }

        cancel()

        self.downloadingModelId = modelId
        status = .downloading
        progress = DownloadProgress()

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let localDir = _MLXModels.cacheDirectory(for: modelId)
                try await self.downloadAllFiles(modelId: modelId, to: localDir)

                if Task.isCancelled {
                    await self.updateStatus(.idle)
                    return
                }

                await self.updateStatus(.completed)
                Self.logger.info("模型下载完成：\(modelId)")

            } catch {
                if !Task.isCancelled {
                    await self.updateStatus(.failed(error.localizedDescription))
                } else {
                    await self.updateStatus(.idle)
                }
                Self.logger.error("模型下载失败：\(modelId), 错误：\(error.localizedDescription)")
            }
        }

        downloadTask = task
        await task.value
    }

    /// 取消下载
    public func cancel() {
        guard status == .downloading else { return }

        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        downloadTask?.cancel()
        downloadTask = nil

        status = .idle
        downloadingModelId = nil
        progress = DownloadProgress()

        Self.logger.info("下载已取消")
    }

    /// 重置状态
    public func reset() {
        cancel()
        status = .idle
    }

    // MARK: - Download Pipeline

    private func downloadAllFiles(modelId: String, to localDir: URL) async throws {
        let files = try await fetchFileList(modelId: modelId)
        let filteredFiles = filterFiles(files)

        guard !filteredFiles.isEmpty else {
            throw DownloadError.noFilesAvailable
        }

        let totalBytes = filteredFiles.reduce(Int64(0)) { $0 + ($1.size ?? 0) }

        await updateProgress(totalFiles: Int64(filteredFiles.count), totalBytes: totalBytes)

        try fileManager.createDirectory(at: localDir, withIntermediateDirectories: true)

        var downloadedBytes: Int64 = 0

        for (index, file) in filteredFiles.enumerated() {
            try Task.checkCancellation()

            let fileURL = localDir.appendingPathComponent(file.path)
            let parentDir = fileURL.deletingLastPathComponent()
            if parentDir != localDir {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            let expectedSize = file.size ?? 0

            // 检查是否已下载
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let existingSize = attrs[.size] as? Int64,
               existingSize == expectedSize, expectedSize > 0 {
                downloadedBytes += expectedSize
                await updateProgress(completedFiles: Int64(index + 1), downloadedBytes: downloadedBytes)
                continue
            }

            // 下载文件
            let bytesWritten = try await downloadSingleFile(
                modelId: modelId,
                remotePath: file.path,
                to: fileURL,
                expectedSize: expectedSize
            )

            downloadedBytes += bytesWritten
            await updateProgress(completedFiles: Int64(index + 1), downloadedBytes: downloadedBytes)
        }

        // 验证 safetensors
        for file in filteredFiles where file.path.hasSuffix(".safetensors") {
            let fileURL = localDir.appendingPathComponent(file.path)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw DownloadError.missingFile(file.path)
            }
            let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
            let size = attrs[.size] as? Int64 ?? 0
            if size == 0 {
                throw DownloadError.emptySafetensorsFile(file.path)
            }
        }
    }

    private func fetchFileList(modelId: String) async throws -> [HFFileEntry] {
        let urlString = "https://huggingface.co/api/models/\(modelId)/tree/main"
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: request)
        let entries = try JSONDecoder().decode([HFFileEntry].self, from: data)

        var allFiles = entries.filter { $0.type == "file" }
        for dir in entries.filter({ $0.type == "directory" }) {
            let subFiles = try await fetchSubdirectory(modelId: modelId, path: dir.path)
            allFiles.append(contentsOf: subFiles)
        }

        return allFiles
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

    private func filterFiles(_ files: [HFFileEntry]) -> [HFFileEntry] {
        let requiredExts: Set<String> = [".safetensors", ".json", ".txt", ".py", ".tiktoken"]
        let requiredNames: Set<String> = ["config.json", "tokenizer.json", "tokenizer_config.json",
                                          "generation_config.json", "special_tokens_map.json"]
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

    private func downloadSingleFile(
        modelId: String,
        remotePath: String,
        to localURL: URL,
        expectedSize: Int64
    ) async throws -> Int64 {
        let encodedPath = remotePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? remotePath
        let urlString = "https://huggingface.co/\(modelId)/resolve/main/\(encodedPath)"
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }

        let incompleteURL = localURL.appendingPathExtension("incomplete")
        self.resumeOffset = 0

        // 检查断点
        if fileManager.fileExists(atPath: incompleteURL.path) {
            let attrs = try fileManager.attributesOfItem(atPath: incompleteURL.path)
            self.resumeOffset = attrs[.size] as? Int64 ?? 0
        }

        // 已存在完整文件
        if fileManager.fileExists(atPath: localURL.path) {
            if let attrs = try? fileManager.attributesOfItem(atPath: localURL.path),
               let size = attrs[.size] as? Int64, size == expectedSize {
                return size
            }
            try? fileManager.removeItem(at: localURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 600
        if resumeOffset > 0 {
            request.setValue("bytes=\(resumeOffset)-", forHTTPHeaderField: "Range")
        }

        // 使用 async/await 下载
        return try await withCheckedThrowingContinuation { continuation in
            let task = downloadSession.downloadTask(with: request)
            task.taskDescription = "\(localURL.path)|\(expectedSize)"
            self.activeDownloadTask = task

            // 存储 continuation 用于回调
            DownloadContext.store(id: task.taskDescription ?? "", continuation: continuation)
            task.resume()
        }
    }

    // MARK: - Status Updates

    @MainActor
    private func updateStatus(_ status: DownloadStatus) {
        self.status = status
        if status == .completed || status == .idle || status == .failed("") {
            self.downloadingModelId = nil
        }
    }

    @MainActor
    private func updateProgress(completedFiles: Int64? = nil, downloadedBytes: Int64? = nil,
                                totalFiles: Int64? = nil, totalBytes: Int64? = nil) {
        if let cf = completedFiles { progress.completedFiles = cf }
        if let tf = totalFiles { progress.totalFiles = tf }
        if let db = downloadedBytes, let tb = totalBytes {
            progress.fractionCompleted = Double(db) / Double(tb) * 0.95
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension MLXDownloadManager: URLSessionDownloadDelegate {

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                          didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                          totalBytesExpectedToWrite: Int64) {
        let currentWritten = resumeOffset + totalBytesWritten
        let currentTotal = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : resumeOffset + totalBytesWritten

        Task { @MainActor [weak self] in
            guard let self, self.status == .downloading else { return }
            self.progress.fractionCompleted = min(0.95, Double(currentWritten) / Double(currentTotal) * 0.95)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                          didFinishDownloadingTo location: URL) {
        guard let taskInfo = downloadTask.taskDescription else { return }
        let parts = taskInfo.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return }

        let destPath = String(parts[0])
        let expectedSize = Int64(parts[1]) ?? 0

        let destURL = URL(fileURLWithPath: destPath)
        let incompleteURL = destURL.appendingPathExtension("incomplete")

        // 处理不同的 HTTP 状态码
        if let response = downloadTask.response as? HTTPURLResponse {
            switch response.statusCode {
            case 200, 206:
                try? fileManager.moveItem(at: location, to: incompleteURL)
            case 416:
                try? fileManager.removeItem(at: incompleteURL)
                try? fileManager.removeItem(at: location)
                // 重试下载
                if let context = DownloadContext.remove(id: taskInfo) {
                    context.resume(returning: 0)  // 返回 0 表示需要重试
                }
                return
            default:
                try? fileManager.removeItem(at: location)
                if let context = DownloadContext.remove(id: taskInfo) {
                    context.resume(throwing: DownloadError.httpError(response.statusCode))
                }
                return
            }
        }

        // 验证并移动文件
        var actualSize: Int64 = 0
        if let attrs = try? fileManager.attributesOfItem(atPath: incompleteURL.path),
           let size = attrs[.size] as? Int64 {
            actualSize = size
            if expectedSize > 0 && size != expectedSize {
                Self.logger.warning("大小不匹配：期望 \(expectedSize), 实际 \(size)")
            }
            try? fileManager.removeItem(at: destURL)
            try? fileManager.moveItem(at: incompleteURL, to: destURL)
        }

        // 完成回调
        if let context = DownloadContext.remove(id: taskInfo) {
            context.resume(returning: expectedSize > 0 ? expectedSize : actualSize)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask,
                          didCompleteWithError error: Error?) {
        guard let taskInfo = task.taskDescription else { return }

        if let error = error {
            Self.logger.error("下载失败：\(error.localizedDescription)")
            if let context = DownloadContext.remove(id: taskInfo) {
                context.resume(throwing: error)
            }
        }
        // 成功情况在 didFinishDownloadingTo 中处理，这里不重复调用 continuation
    }
}

// MARK: - Supporting Types

public enum DownloadStatus: Equatable, Sendable {
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

public struct DownloadProgress: Sendable {
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

private struct HFFileEntry: Decodable {
    let type: String
    let path: String
    let size: Int64?
}

public enum DownloadError: LocalizedError {
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

// MARK: - DownloadContext (Continuation Storage)

private final class DownloadContext: @unchecked Sendable {
    private static let _continuations = LockedDictionary<String, DownloadContext>()

    let continuation: CheckedContinuation<Int64, Error>
    let id: String

    private init(id: String, continuation: CheckedContinuation<Int64, Error>) {
        self.id = id
        self.continuation = continuation
    }

    static func store(id: String, continuation: CheckedContinuation<Int64, Error>) {
        _continuations.setValue(DownloadContext(id: id, continuation: continuation), forKey: id)
    }

    static func remove(id: String) -> DownloadContext? {
        _continuations.removeValue(forKey: id)
    }

    func resume(returning value: Int64) {
        continuation.resume(returning: value)
    }

    func resume(throwing error: Error) {
        continuation.resume(throwing: error)
    }
}

// Thread-safe dictionary wrapper
private final class LockedDictionary<Key: Hashable, Value>: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.lumi.downloadcontext.lock")
    private var _storage: [Key: Value] = [:]

    func setValue(_ value: Value, forKey key: Key) {
        queue.async { self._storage[key] = value }
    }

    func removeValue(forKey key: Key) -> Value? {
        queue.sync { _storage.removeValue(forKey: key) }
    }
}
