import DownloadKit
import Testing
import Foundation

@Suite("ResumeHandler Tests")
struct ResumeHandlerTests {

    private func withTempDir(_ body: (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResumeHandlerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try await body(tempDir)
    }

    @Test("保存和获取断点续传数据")
    func saveAndGetResumeData() async throws {
        let handler = ResumeHandler()
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let data = Data("resume data".utf8)

        await handler.saveResumeData(for: url, data: data)
        let retrieved = await handler.getResumeData(for: url)

        #expect(retrieved == data)
    }

    @Test("移除断点续传数据")
    func removeResumeData() async throws {
        let handler = ResumeHandler()
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let data = Data("resume data".utf8)

        await handler.saveResumeData(for: url, data: data)
        await handler.removeResumeData(for: url)
        let retrieved = await handler.getResumeData(for: url)

        #expect(retrieved == nil)
    }

    @Test("获取不存在的断点续传数据返回 nil")
    func getNonExistentResumeData() async throws {
        let handler = ResumeHandler()
        let url = URL(fileURLWithPath: "/tmp/nonexistent.txt")

        let retrieved = await handler.getResumeData(for: url)
        #expect(retrieved == nil)
    }

    @Test("获取部分文件大小")
    func getPartialFileSize() async throws {
        try await withTempDir { tempDir in
            let handler = ResumeHandler()
            let fileURL = tempDir.appendingPathComponent("partial.txt")
            let content = "Partial content"
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            let size = await handler.getPartialFileSize(at: fileURL)
            #expect(size == Int64(content.utf8.count))
        }
    }

    @Test("不存在的部分文件大小为 0")
    func getPartialFileSizeForNonExistent() async throws {
        try await withTempDir { tempDir in
            let handler = ResumeHandler()
            let fileURL = tempDir.appendingPathComponent("nonexistent.txt")

            let size = await handler.getPartialFileSize(at: fileURL)
            #expect(size == 0)
        }
    }

    @Test("追加数据到文件")
    func appendData() async throws {
        try await withTempDir { tempDir in
            let handler = ResumeHandler()
            let fileURL = tempDir.appendingPathComponent("append.txt")

            let data1 = Data("Hello, ".utf8)
            let data2 = Data("World!".utf8)

            try await handler.appendData(data1, to: fileURL)
            try await handler.appendData(data2, to: fileURL)

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            #expect(content == "Hello, World!")
        }
    }

    @Test("完成下载重命名文件")
    func finalizeDownload() async throws {
        try await withTempDir { tempDir in
            let handler = ResumeHandler()
            let incompleteURL = tempDir.appendingPathComponent("file.txt.incomplete")
            let finalURL = tempDir.appendingPathComponent("file.txt")

            try "Complete content".write(to: incompleteURL, atomically: true, encoding: .utf8)

            try await handler.finalizeDownload(from: incompleteURL, to: finalURL)

            #expect(!FileManager.default.fileExists(atPath: incompleteURL.path))
            #expect(FileManager.default.fileExists(atPath: finalURL.path))

            let content = try String(contentsOf: finalURL, encoding: .utf8)
            #expect(content == "Complete content")
        }
    }

    @Test("完成下载覆盖已存在的文件")
    func finalizeDownloadOverwrite() async throws {
        try await withTempDir { tempDir in
            let handler = ResumeHandler()
            let incompleteURL = tempDir.appendingPathComponent("file.txt.incomplete")
            let finalURL = tempDir.appendingPathComponent("file.txt")

            try "Old content".write(to: finalURL, atomically: true, encoding: .utf8)
            try "New content".write(to: incompleteURL, atomically: true, encoding: .utf8)

            try await handler.finalizeDownload(from: incompleteURL, to: finalURL)

            let content = try String(contentsOf: finalURL, encoding: .utf8)
            #expect(content == "New content")
        }
    }
}
