import Foundation
import KitAgentTool
import Testing
@testable import PluginToolManager

/// read_file 大文件分块读取回归（#393）。
///
/// 旧实现先检查整文件大小，超过 10 MiB 立即拒绝，offset/limit 还没被读取，
/// 于是任何大文件都无法分块读取。修复后：显式 offset/limit 的有界分块读取
/// 不受总大小否决；未指定范围的整文件读取仍受 10 MiB 限制；输出仍受
/// 250 行 / 30,000 字符上限约束。
@MainActor
private func withLargeTempFile(
    lineCount: Int = 150_000,
    _ body: (String) async throws -> Void
) async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-read-large-\(UUID().uuidString).txt")
    // 每行约 80 字节，150k 行 ≈ 12 MiB，确定超过 10 MiB 上限。
    let padding = String(repeating: "x", count: 70)
    let text = (1...lineCount).map { "line \($0) \(padding)" }.joined(separator: "\n")
    try text.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    try await body(url.path)
}

@MainActor
@Test func readFileAllowsChunkedReadOfLargeFile() async throws {
    try await withLargeTempFile { path in
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: [
            "path": ToolArgument(path),
            "offset": ToolArgument(1),
            "limit": ToolArgument(1),
        ])
        #expect(result.hasPrefix("1\tline 1 "))
        #expect(!result.contains("too large"))
    }
}

@MainActor
@Test func readFileLargeFileWholeReadStillRejected() async throws {
    try await withLargeTempFile { path in
        let tool = ReadFileTool()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: ["path": ToolArgument(path)])
        }
    }
}

@MainActor
@Test func readFileLargeFileChunkRespectsLineLimit() async throws {
    try await withLargeTempFile { path in
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: [
            "path": ToolArgument(path),
            "offset": ToolArgument(1),
            "limit": ToolArgument(250),
        ])
        #expect(result.contains("250\tline 250 "))
        #expect(!result.contains("251\tline 251 "))
        #expect(result.contains("use offset/limit to read more"))
    }
}

@MainActor
@Test func readFileLargeFileMiddleChunk() async throws {
    try await withLargeTempFile { path in
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: [
            "path": ToolArgument(path),
            "offset": ToolArgument(100_000),
            "limit": ToolArgument(2),
        ])
        #expect(result.contains("100000\tline 100000 "))
        #expect(result.contains("100001\tline 100001 "))
        #expect(!result.contains("100002\tline 100002 "))
    }
}