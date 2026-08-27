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
        refreshDownloadState()
    }

    public func refreshDownloadState() {
        stateSubject?.send(downloadState)
    }

    public func configure(rootDirectory: URL) {
        isShutdown = false
        MLXModelPaths.configure(rootDirectory: rootDirectory)
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
        UserDefaults.standard.set(bytesPerSecond ?? 0, forKey: Self.downloadSpeedLimitKey)
        let manager = downloadManager
        Task { await manager.setMaxBytesPerSecond(bytesPerSecond) }
        refreshDownloadState()
    }

    nonisolated public func currentSpeedLimitBytes() -> Int {
        let value = UserDefaults.standard.object(forKey: Self.downloadSpeedLimitKey) as? Int ?? 0
        return max(0, value)
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

                do {
                    _ = try await downloadManager.download(task) { [weak self] fileProgress in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.currentFileDownloadedBytes = fileProgress.downloadedBytes
                            self.publishProgress(
                                operationID: operationID,
                                completedBytes: completedBytes,
                                currentBytes: fileProgress.downloadedBytes,
                                completedFiles: completedFiles,
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
        LLMModelDownloadState(
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
            downloadedModelIDs: downloadedModelIDs,
            cacheSizeBytes: cacheSizeBytes,
            speedLimitBytesPerSecond: downloadSpeedLimit
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

    private var cacheSizeBytes: Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: modelCacheDirectoryURL,
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
        let value = UserDefaults.standard.object(forKey: downloadSpeedLimitKey) as? Int ?? 0
        return value > 0 ? value : nil
    }
}
