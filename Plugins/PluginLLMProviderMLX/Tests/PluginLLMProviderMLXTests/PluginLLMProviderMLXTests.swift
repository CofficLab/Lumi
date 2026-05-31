import Foundation
import Testing
@testable import PluginLLMProviderMLX

@Test func packageLoads() async throws {
    #expect(MLXPlugin.id == "LLMProviderMLX")
}

@Test func modelCacheDirectoryStaysInsideModelsCacheRoot() throws {
    let root = MLXModels.modelsCacheBaseDirectory.standardizedFileURL.path

    for modelId in ["Qwen/Qwen3-0.6B-4bit", "../escape", "org/../escape", "", "."] {
        let path = MLXModels.cacheDirectory(for: modelId).standardizedFileURL.path
        #expect(path == root || path.hasPrefix(root + "/"))
        #expect(!path.components(separatedBy: "/").contains(".."))
    }
}

@Test func finalizedDownloadReplacesDestinationWithCompleteFile() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let location = directory.appendingPathComponent("download.tmp")
    let destination = directory.appendingPathComponent("model.safetensors")

    try "old".write(to: destination, atomically: true, encoding: .utf8)
    try "complete".write(to: location, atomically: true, encoding: .utf8)

    let size = try MLXDownloadManager.finalizeDownloadedFile(
        from: location,
        to: destination,
        expectedSize: 8,
        statusCode: 200
    )

    #expect(size == 8)
    #expect(try String(contentsOf: destination, encoding: .utf8) == "complete")
    #expect(!FileManager.default.fileExists(atPath: location.path))
}

@Test func finalizedDownloadAppendsPartialContentForResumeResponse() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let location = directory.appendingPathComponent("download.tmp")
    let destination = directory.appendingPathComponent("model.safetensors")
    let incomplete = destination.appendingPathExtension("incomplete")

    try "partial-".write(to: incomplete, atomically: true, encoding: .utf8)
    try "rest".write(to: location, atomically: true, encoding: .utf8)

    let size = try MLXDownloadManager.finalizeDownloadedFile(
        from: location,
        to: destination,
        expectedSize: 12,
        statusCode: 206
    )

    #expect(size == 12)
    #expect(try String(contentsOf: destination, encoding: .utf8) == "partial-rest")
    #expect(!FileManager.default.fileExists(atPath: incomplete.path))
    #expect(!FileManager.default.fileExists(atPath: location.path))
}

@Test func finalizedDownloadRejectsSizeMismatch() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let location = directory.appendingPathComponent("download.tmp")
    let destination = directory.appendingPathComponent("model.safetensors")
    let incomplete = destination.appendingPathExtension("incomplete")

    try "short".write(to: location, atomically: true, encoding: .utf8)

    #expect(throws: DownloadError.self) {
        _ = try MLXDownloadManager.finalizeDownloadedFile(
            from: location,
            to: destination,
            expectedSize: 100,
            statusCode: 200
        )
    }
    #expect(!FileManager.default.fileExists(atPath: destination.path))
    #expect(!FileManager.default.fileExists(atPath: incomplete.path))
}

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

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLLMProviderMLXTests")
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
