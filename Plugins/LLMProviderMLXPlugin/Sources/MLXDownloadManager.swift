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
    nonisolated public static let verbose: Bool = false

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

    private let fileManager = FileManager.default
    private let downloadManager: DownloadManager

    // MARK: - Pause/Resume State

    private var pausedModelId: String?
    private var pausedProgress: MLXDownloadProgress?
    private var pausedFileIndex: Int?
    private var pausedDownloadedBytes: Int64?

    // MARK: - Initialization

    private override init() {
        let config = DownloadManager.Configuration(
            downloadDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("lumi-mlx-download"),
            maxConcurrentDownloads: 3,
            timeoutInterval: 3600,
            enableResume: true
        )
        self.downloadManager = DownloadManager(configuration: config)

        super.init()

        try? fileManager.createDirectory(at: config.downloadDirectory, withIntermediateDirectories: true)

        if Self.verbose {
            Self.logger.info("\(self.t)MLXDownloadManager 已初始化")
        }
    }

    deinit {
        downloadTask?.cancel()
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

        downloadingModelId = modelId
        status = .downloading
        progress = MLXDownloadProgress()

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
                    Self.logger.info("\(self.t)下载任务被取消：\(modelId)")
                    self.status = .idle
                    self.downloadingModelId = nil
                    return
                }

                self.status = .completed
                self.downloadingModelId = nil
                Self.logger.info("\(self.t)✅ 模型下载完成：\(modelId)")

            } catch {
                if !Task.isCancelled {
                    self.status = .failed(error.localizedDescription)
                    self.downloadingModelId = nil
                    Self.logger.error("\(self.t)❌ 模型下载失败：\(modelId)\n错误类型：\(type(of: error))\n错误详情：\(error.localizedDescription)")
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

    /// 暂停下载
    public func pause() {
        guard status == .downloading, let modelId = downloadingModelId else {
            Self.logger.warning("\(self.t)无法暂停：当前未在下载")
            return
        }

        Self.logger.info("\(self.t)⏸️ 暂停下载：\(modelId)")

        // 保存当前状态
        pausedModelId = modelId
        pausedProgress = progress
        pausedDownloadedBytes = calculateTotalDownloadedBytes()

        // 设置状态为暂停
        status = .paused

        // 取消当前下载任务（但不重置状态）
        downloadTask?.cancel()
        downloadTask = nil

        // 取消 DownloadKit 中的任务
        let dm = downloadManager
        Task {
            await dm.cancelAll()
        }
    }

    /// 恢复下载
    public func resume() async {
        guard status == .paused, let modelId = pausedModelId else {
            Self.logger.warning("\(self.t)无法恢复：当前未暂停")
            return
        }

        Self.logger.info("\(self.t)▶️ 恢复下载：\(modelId)")

        // 恢复状态
        downloadingModelId = modelId
        status = .downloading

        if let savedProgress = pausedProgress {
            progress = savedProgress
        }

        // 清除暂停状态
        pausedModelId = nil
        pausedProgress = nil

        // 重新启动下载
        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let localDir = _MLXModels.cacheDirectory(for: modelId)
                let startIndex = Int(self.progress.completedFiles)

                try await self.downloadAllFiles(modelId: modelId, to: localDir, startIndex: startIndex)

                if Task.isCancelled {
                    self.status = .idle
                    self.downloadingModelId = nil
                    return
                }

                self.status = .completed
                self.downloadingModelId = nil
                Self.logger.info("\(self.t)✅ 模型下载完成：\(modelId)")

            } catch {
                if !Task.isCancelled {
                    self.status = .failed(error.localizedDescription)
                    self.downloadingModelId = nil
                    Self.logger.error("\(self.t)❌ 模型下载失败：\(modelId) - \(error.localizedDescription)")
                } else {
                    self.status = .idle
                    self.downloadingModelId = nil
                }
            }
        }

        downloadTask = task
        await task.value
    }

    private func calculateTotalDownloadedBytes() -> Int64 {
        // 简化实现：根据已完成文件数估算
        guard let modelId = downloadingModelId else { return 0 }

        // 这里需要根据实际下载的文件大小计算，暂时返回 0
        // 后续可以从 DownloadKit 获取更精确的值
        return 0
    }

    private func cancel(resetPublishedState shouldResetPublishedState: Bool) {
        downloadTask?.cancel()
        downloadTask = nil

        // 取消 DownloadKit 中的所有任务
        let dm = downloadManager
        Task {
            await dm.cancelAll()
        }

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

        downloadTask?.cancel()
        downloadTask = nil

        let dm = downloadManager
        Task {
            await dm.cancelAll()
        }

        resetPublishedState()
    }

    /// 重置状态
    public func reset() {
        cancel()
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

        // 如果从中间开始，先计算已下载文件的总大小
        if startIndex > 0 {
            for index in 0..<startIndex {
                let file = filteredFiles[index]
                downloadedBytes += file.size ?? 0
            }
            updateProgress(completedFiles: Int64(startIndex), downloadedBytes: downloadedBytes)
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

            // 检查是否已下载
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let existingSize = attrs[.size] as? Int64 {
                if existingSize == expectedSize, expectedSize > 0 {
                    Self.logger.info("\(self.t)⏭️ 文件已存在，跳过：\(file.path)")
                    downloadedBytes += expectedSize
                    updateProgress(completedFiles: Int64(index + 1), downloadedBytes: downloadedBytes)
                    continue
                } else if expectedSize > 0 {
                    // 文件存在但大小不匹配，删除旧文件重新下载
                    Self.logger.warning("\(self.t)⚠️ 文件大小不匹配，删除旧文件：\(file.path) (期望 \(expectedSize), 实际 \(existingSize))")
                    try? fileManager.removeItem(at: fileURL)
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

            // 更新当前下载的文件名和大小
            currentFileName = file.path
            currentFileSize = expectedSize
            currentFileDownloadedBytes = 0

            let task = DownloadTask(
                id: file.path,
                url: url,
                destination: fileURL,
                expectedSize: expectedSize
            )

            do {
                _ = try await dm.download(task) { [weak self] progress in
                    Task { @MainActor in
                        self?.currentFileDownloadedBytes = progress.downloadedBytes
                    }
                }
                downloadedBytes += expectedSize
                updateProgress(completedFiles: Int64(index + 1), downloadedBytes: downloadedBytes)
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
                                totalFiles: Int64? = nil, totalBytes: Int64? = nil) {
        if let cf = completedFiles { progress.completedFiles = cf }
        if let tf = totalFiles { progress.totalFiles = tf }
        if let db = downloadedBytes, let tb = totalBytes {
            progress.fractionCompleted = Self.downloadProgressFraction(
                writtenBytes: db,
                totalBytes: tb
            )
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
