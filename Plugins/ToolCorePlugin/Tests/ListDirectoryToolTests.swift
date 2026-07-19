import Foundation
import LumiKernel
import Testing
@testable import ToolCorePlugin

private func makeContext(allowed: [String] = []) -> LumiToolExecutionContext {
    LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "test",
        toolName: "ls",
        allowedDirectories: allowed
    )
}

@Suite(.serialized)
final class ListDirectoryToolTests {
    private var tmpDir: URL!

    init() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ToolCorePlugin.ls.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    @Test func listsFlatDirectory() async throws {
        try FileManager.default.createDirectory(at: tmpDir.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try "hello".write(to: tmpDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "world".write(to: tmpDir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        let tool = ListDirectoryTool()
        let result = try await tool.execute(arguments: ["path": .string(tmpDir.path)], context: makeContext())
        #expect(result.contains("a.txt"))
        #expect(result.contains("b.txt"))
        #expect(result.contains("sub/"))
    }

    @Test func listsRecursively() async throws {
        let sub = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "content".write(to: sub.appendingPathComponent("deep.txt"), atomically: true, encoding: .utf8)

        let tool = ListDirectoryTool()
        let result = try await tool.execute(
            arguments: ["path": .string(tmpDir.path), "recursive": .bool(true)],
            context: makeContext()
        )
        #expect(result.contains("deep.txt"))
    }

    @Test func returnsErrorForNonexistentDirectory() async throws {
        let tool = ListDirectoryTool()
        let result = try await tool.execute(
            arguments: ["path": .string("/tmp/nonexistent_\(UUID().uuidString)")],
            context: makeContext()
        )
        #expect(result.contains("Error"))
    }

    @Test func throwsWhenPathMissing() async throws {
        let tool = ListDirectoryTool()
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: [:], context: makeContext())
        }
    }

    @Test func throwsWhenPathDenied() async throws {
        let tool = ListDirectoryTool()
        let denied = makeContext(allowed: ["/tmp/allowed_only"])
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: ["path": .string(tmpDir.path)], context: denied)
        }
    }

    @Test func truncatesLargeDirectory() async throws {
        for i in 0..<600 {
            try "".write(to: tmpDir.appendingPathComponent("f\(i).txt"), atomically: true, encoding: .utf8)
        }

        let tool = ListDirectoryTool()
        let result = try await tool.execute(arguments: ["path": .string(tmpDir.path)], context: makeContext())
        #expect(result.contains("truncated"))
    }

    @Test func displayDescriptionShowsDirectoryName() {
        let tool = ListDirectoryTool()
        let desc = tool.displayDescription(arguments: ["path": .string("/Users/angel/Code")])
        #expect(desc.contains("Code"))
    }

    @Test func displayDescriptionFallbackWhenNoPath() {
        let tool = ListDirectoryTool()
        let desc = tool.displayDescription(arguments: [:])
        #expect(desc.contains("列出目录"))
    }

    @Test func riskLevelIsLow() {
        let tool = ListDirectoryTool()
        #expect(tool.riskLevel(arguments: [:], context: nil) == .low)
    }
}
