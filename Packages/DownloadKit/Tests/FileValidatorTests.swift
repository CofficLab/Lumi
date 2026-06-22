import DownloadKit
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

    @Test("验证空文件抛出错误")
    func validateEmptyFile() async throws {
        try await withTempDir { tempDir in
            let fileURL = tempDir.appendingPathComponent("empty.txt")
            try Data().write(to: fileURL)

            #expect(throws: DownloadError.self) {
                try validator.validate(fileAt: fileURL)
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
