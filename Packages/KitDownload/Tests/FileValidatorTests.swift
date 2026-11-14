import KitDownload
import Testing
import Foundation

@Suite("FileValidator Tests")
struct FileValidatorTests {

    private let validator = FileValidator()

    private func withTempDir(_ body: (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileValidatorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try await body(tempDir)
    }

    @Test("验证存在的文件")
    func validateExistingFile() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("test.txt")
            try "Hello, World!".write(to: fileURL, atomically: true, encoding: .utf8)

            let result = try validator.validate(fileAt: fileURL)
            #expect(result == true)
        }
    }

    @Test("验证不存在的文件抛出错误")
    func validateNonExistentFile() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("nonexistent.txt")

            #expect(throws: DownloadError.self) {
                try validator.validate(fileAt: fileURL)
            }
        }
    }

    /// 回归 #159：validate 仅在 HTTP 200/206 成功返回后调用，干净返回的零字节
    /// 是合法资源。无期望大小时不得一律判为 emptyFile 失败（旧契约错误地锁定抛出）。
    @Test("无期望大小时合法空文件必须验证成功，不得误判为空文件失败")
    func validateEmptyFileWithoutExpectationSucceeds() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("empty.txt")
            try Data().write(to: fileURL)

            let result = try validator.validate(fileAt: fileURL)
            #expect(result == true)
        }
    }

    /// 回归 #159：期望 0 字节且实际 0 字节是合法下载，大小匹配必须先于空文件判断，
    /// 否则 expectedSize == 0 永远无法通过。
    @Test("期望大小为零的空文件必须验证成功，不得误判失败")
    func validateZeroByteFileWithExpectedZero() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("empty.txt")
            try Data().write(to: fileURL)

            let result = try validator.validate(fileAt: fileURL, expectedSize: 0)
            #expect(result == true)
        }
    }

    /// 期望 0 字节仍须严格校验：实际非空时按大小不匹配抛出，而非放行。
    @Test("期望大小为零但文件非空时抛出大小不匹配")
    func validateNonEmptyFileWithExpectedZeroThrows() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("nonempty.txt")
            try "Hello".write(to: fileURL, atomically: true, encoding: .utf8)

            #expect(throws: DownloadError.self) {
                try validator.validate(fileAt: fileURL, expectedSize: 0)
            }
        }
    }

    @Test("验证文件大小不匹配抛出错误")
    func validateSizeMismatch() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("wrong_size.txt")
            try "Hello".write(to: fileURL, atomically: true, encoding: .utf8)

            #expect(throws: DownloadError.self) {
                try validator.validate(fileAt: fileURL, expectedSize: 100)
            }
        }
    }

    @Test("验证文件大小匹配成功")
    func validateSizeMatch() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("correct_size.txt")
            let content = "Hello, World!"
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            let expectedSize = Int64(content.utf8.count)
            let result = try validator.validate(fileAt: fileURL, expectedSize: expectedSize)
            #expect(result == true)
        }
    }

    @Test("检查完整文件")
    func isCompleteWithCompleteFile() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("complete.txt")
            let content = "Complete content"
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            let isComplete = validator.isComplete(fileAt: fileURL, expectedSize: Int64(content.utf8.count))
            #expect(isComplete == true)
        }
    }

    @Test("检查不完整文件")
    func isCompleteWithIncompleteFile() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("incomplete.txt")
            try "Short".write(to: fileURL, atomically: true, encoding: .utf8)

            let isComplete = validator.isComplete(fileAt: fileURL, expectedSize: 100)
            #expect(isComplete == false)
        }
    }

    @Test("检查不存在的文件返回 false")
    func isCompleteWithNonExistentFile() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("nonexistent.txt")

            let isComplete = validator.isComplete(fileAt: fileURL, expectedSize: 100)
            #expect(isComplete == false)
        }
    }
}
