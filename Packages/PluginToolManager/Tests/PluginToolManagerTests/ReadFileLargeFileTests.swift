import Foundation
import KitAgentTool
import Testing
@testable import PluginToolManager

/// read_file 大文件分块读取回归（#393）。
///
/// 旧实现先检查整文件大小，超过 10 MiB 立即拒绝，offset/limit 还没被读取，
/// 于是任何大文件都无法分块读取。修复后：显式 offset/limit 的有界分块读取
/// 不受总大小否决；未指定范围的整文件读取仍受 10 MiB 限制；输出仍受
/// 2000 行 / 100,000 字符上限约束（#1320），两种截断都附精确续读偏移。
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
        #expect(result.contains("continue with offset=251"))
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

// MARK: - 输出上限与续读提示（#1320）

@MainActor
private func withSizedTempFile(
    lineCount: Int,
    paddingCount: Int = 0,
    _ body: (String) async throws -> Void
) async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-read-limit-\(UUID().uuidString).txt")
    let padding = String(repeating: "x", count: paddingCount)
    let text = (1...lineCount).map { "\(padding)line \($0)" }.joined(separator: "\n")
    try text.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    try await body(url.path)
}

/// 1,500 行的普通源码文件（短行）默认一次调用读完整，无需续读。
@MainActor
@Test func readFileDefaultLimitReturns1500LineFileInOneCall() async throws {
    try await withSizedTempFile(lineCount: 1_500) { path in
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: ["path": ToolArgument(path)])
        #expect(result.hasPrefix("1\tline 1"))
        #expect(result.contains("1500\tline 1500"))
        #expect(!result.contains("truncated"))
        #expect(!result.contains("continue with offset="))
    }
}

/// limit 超过上限时钳到 2000，行区间截断附精确续读偏移。
@MainActor
@Test func readFileClampsLimitTo2000AndHintsNextOffset() async throws {
    try await withSizedTempFile(lineCount: 2_500) { path in
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: [
            "path": ToolArgument(path),
            "limit": ToolArgument(5_000),
        ])
        #expect(result.contains("2000\tline 2000"))
        #expect(!result.contains("2001\tline 2001"))
        #expect(result.contains("continue with offset=2001"))
    }
}

/// 字符预算截断附精确续读偏移；按提示续读无缺口、无重复。
@MainActor
@Test func readFileCharBudgetTruncationHintsLosslessContinuation() async throws {
    try await withSizedTempFile(lineCount: 2_500, paddingCount: 70) { path in
        let tool = ReadFileTool()
        let first = try await tool.execute(arguments: ["path": ToolArgument(path)])
        #expect(first.contains("output truncated at 100000 characters"))
        guard let match = first.firstMatch(of: /continue with offset=(\d+)/) else {
            Issue.record("missing continuation hint: \(first.suffix(200))")
            return
        }
        let nextOffset = Int(match.1)!
        #expect(nextOffset > 1 && nextOffset <= 2_000)
        // 续读起点的前一行是最后一个已输出行：无缺口。
        #expect(first.contains("\(nextOffset - 1)\txxx"))

        let second = try await tool.execute(arguments: [
            "path": ToolArgument(path),
            "offset": ToolArgument(nextOffset),
        ])
        #expect(second.hasPrefix("\(nextOffset)\txxx"))
        // 上一次最后输出的行不再出现：无重复。
        #expect(!second.contains("xxxline \(nextOffset - 1)"))
    }
}

/// schema 声明的 limit 上限与实现常量一致（AGENTS.md 约定）。
@MainActor
@Test func readFileSchemaMaximumMatchesLimitCap() throws {
    let tool = ReadFileTool()
    let schema = tool.inputSchema(for: .english)
    let properties = schema["properties"] as? [String: Any]
    let limit = properties?["limit"] as? [String: Any]
    #expect(limit?["maximum"] as? Int == 2000)
    #expect(limit?["minimum"] as? Int == 1)
}