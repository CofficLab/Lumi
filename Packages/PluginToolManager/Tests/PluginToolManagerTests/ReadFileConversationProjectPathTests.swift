import Foundation
import KitAgentTool
import Testing
@testable import PluginToolManager

/// read_file 会话项目路径回归（#501）。
///
/// `ToolExecutionContext.conversationProjectPath()` 曾把 provider 返回的路径
/// trim 后再返回，目录名带合法尾部空格时（如 `/tmp/lumi `）相对路径工具会解析到
/// 另一个项目（`/tmp/lumi`）。上游 KitAgentTool 1.0.2 改为仅用 trim 做空判断、
/// 返回原始字节。这里端到端锁定 read_file 按会话绑定的原始路径读取，而不是 UI
/// 当前项目或被 trim 过的同名诱饵目录。

@MainActor
private func withProjectPair(
    _ body: (_ plain: String, _ spaced: String) async throws -> Void
) async throws {
    let plain = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-501-\(UUID().uuidString)", isDirectory: true)
        .path
    let spaced = plain + " "
    try FileManager.default.createDirectory(atPath: plain, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(atPath: spaced, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(atPath: plain)
        try? FileManager.default.removeItem(atPath: spaced)
    }
    try "PLAIN".write(toFile: plain + "/marker.txt", atomically: true, encoding: .utf8)
    try "SPACED".write(toFile: spaced + "/marker.txt", atomically: true, encoding: .utf8)
    try await body(plain, spaced)
}

@MainActor
@Test func readFileUsesConversationProjectWithTrailingSpace() async throws {
    try await withProjectPair { _, spaced in
        let context = ToolExecutionContext(
            jobID: "job-501-trailing",
            conversationID: UUID(),
            conversationProjectPathProvider: { spaced }
        )

        let result = try await ReadFileTool().executeResult(
            context: context,
            arguments: ["path": ToolArgument("marker.txt")]
        )

        #expect(result.content.contains("SPACED"))
        #expect(!result.content.contains("PLAIN"))
    }
}

@MainActor
@Test func readFileUsesConversationProjectWithoutSpace() async throws {
    try await withProjectPair { plain, _ in
        let context = ToolExecutionContext(
            jobID: "job-501-plain",
            conversationID: UUID(),
            conversationProjectPathProvider: { plain }
        )

        let result = try await ReadFileTool().executeResult(
            context: context,
            arguments: ["path": ToolArgument("marker.txt")]
        )

        #expect(result.content.contains("PLAIN"))
        #expect(!result.content.contains("SPACED"))
    }
}