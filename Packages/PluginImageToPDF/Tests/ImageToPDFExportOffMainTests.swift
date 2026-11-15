import Foundation
import Testing
@testable import ImageToPDFPlugin

/// 回归 #1197：导出 PDF 时目录准备与逐文件复制必须在后台线程，
/// 主线程只快照源/目标并发布结果，保留覆盖与同名目录拒绝行为。
@Suite("Image-to-PDF export off-main")
struct ImageToPDFExportOffMainTests {

    @Test("copyOutputs 在后台线程复制并原子覆盖已存在的同名 PDF")
    func copiesOffMain() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let srcDir = root.appendingPathComponent("src", isDirectory: true)
        let dstDir = root.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true)
        let a = srcDir.appendingPathComponent("a.pdf")
        let b = srcDir.appendingPathComponent("b.pdf")
        try Data("AAA".utf8).write(to: a)
        try Data("BBB".utf8).write(to: b)
        try Data("OLD".utf8).write(to: dstDir.appendingPathComponent("a.pdf"))

        let flag = ThreadFlag()
        let result = try await Task.detached(priority: .userInitiated) {
            try runCopyOffMain([a, b], to: dstDir, flag: flag)
        }.value

        #expect(flag.value == false, "文件复制不应发生在主线程")
        #expect(result.written == 2)
        #expect(result.failed.isEmpty)
        #expect(try Data(contentsOf: dstDir.appendingPathComponent("a.pdf")) == Data("AAA".utf8))
        #expect(try Data(contentsOf: dstDir.appendingPathComponent("b.pdf")) == Data("BBB".utf8))
        let residue = try FileManager.default.contentsOfDirectory(atPath: dstDir.path)
            .filter { $0.hasPrefix(".export-") }
        #expect(residue.isEmpty, "不应留下临时文件")
    }

    @Test("目标是同名目录时拒绝导出并保留目录内容")
    func rejectsDirectoryConflictOffMain() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let srcDir = root.appendingPathComponent("src", isDirectory: true)
        let dstDir = root.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true)
        let a = srcDir.appendingPathComponent("a.pdf")
        try Data("AAA".utf8).write(to: a)
        let conflictDir = dstDir.appendingPathComponent("a.pdf", isDirectory: true)
        try FileManager.default.createDirectory(at: conflictDir, withIntermediateDirectories: true)
        let keep = conflictDir.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: keep)

        let result = await Task.detached(priority: .userInitiated) {
            ImageToPDFViewModel.copyOutputs([a], to: dstDir)
        }.value

        #expect(result.written == 0)
        #expect(result.failed == ["a.pdf"])
        #expect(try Data(contentsOf: keep) == Data("keep".utf8), "同名目录内容必须保留")
    }
}

// MARK: - Helpers

/// 同步函数：在后台线程记录是否主线程并执行复制。
/// `Thread.isMainThread` 不能直接在 async 闭包里引用，故包进同步函数。
private func runCopyOffMain(
    _ sources: [URL],
    to directory: URL,
    flag: ThreadFlag
) throws -> (written: Int, failed: [String]) {
    flag.value = Thread.isMainThread
    return ImageToPDFViewModel.copyOutputs(sources, to: directory)
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}