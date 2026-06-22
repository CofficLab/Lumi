import Foundation
import Testing
@testable import LLMProviderMLXPlugin

@Test func packageLoads() async throws {
    #expect(MLXLumiPlugin.info.id == "com.coffic.lumi.plugin.llm-provider.mlx")
    #expect(MLXLumiPlugin.info.displayName.isEmpty == false)
}

@Test func modelCacheDirectoryStaysInsideModelsCacheRoot() throws {
    let root = MLXModels.modelsCacheBaseDirectory.standardizedFileURL.path

    for modelId in ["Qwen/Qwen3-0.6B-4bit", "../escape", "org/../escape", "", "."] {
        let path = MLXModels.cacheDirectory(for: modelId).standardizedFileURL.path
        #expect(path == root || path.hasPrefix(root + "/"))
        #expect(!path.components(separatedBy: "/").contains(".."))
    }
}

@MainActor
@Test func downloadProgressFractionStaysFiniteForUnknownTotals() {
    #expect(MLXDownloadManager.downloadProgressFraction(writtenBytes: 0, totalBytes: 0) == 0)
    #expect(MLXDownloadManager.downloadProgressFraction(writtenBytes: 100, totalBytes: 0) == 0)
    #expect(MLXDownloadManager.downloadProgressFraction(writtenBytes: -1, totalBytes: 100) == 0)

    let partial = MLXDownloadManager.downloadProgressFraction(writtenBytes: 50, totalBytes: 100)
    #expect(partial.isFinite)
    #expect(partial == 0.475)

    let overComplete = MLXDownloadManager.downloadProgressFraction(writtenBytes: 200, totalBytes: 100)
    #expect(overComplete == 0.95)
}

@Test func mlxDownloadErrorDescriptionsAreValid() {
    let errors: [MLXDownloadError] = [
        .invalidURL,
        .invalidResponse,
        .httpError(404),
        .noFilesAvailable,
        .missingFile("test.txt"),
        .emptySafetensorsFile("empty.safetensors"),
        .sizeMismatch(100, 50),
        .downloadFailed("test failure")
    ]

    for error in errors {
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }
}

@Test func mlxDownloadStatusEquality() {
    #expect(MLXDownloadStatus.idle == MLXDownloadStatus.idle)
    #expect(MLXDownloadStatus.downloading == MLXDownloadStatus.downloading)
    #expect(MLXDownloadStatus.completed == MLXDownloadStatus.completed)
    #expect(MLXDownloadStatus.failed("error") == MLXDownloadStatus.failed("error"))
    #expect(MLXDownloadStatus.failed("error1") != MLXDownloadStatus.failed("error2"))
    #expect(MLXDownloadStatus.idle != MLXDownloadStatus.downloading)
}

@Test func mlxDownloadProgressLabels() {
    var progress = MLXDownloadProgress()
    progress.fractionCompleted = 0.5
    #expect(progress.percentLabel == "50%")

    progress.speed = 1024 * 1024 // 1 MB/s
    #expect(progress.speedLabel.contains("MB"))

    progress.speed = 0
    #expect(progress.speedLabel.isEmpty)
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLLMProviderMLXTests")
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
