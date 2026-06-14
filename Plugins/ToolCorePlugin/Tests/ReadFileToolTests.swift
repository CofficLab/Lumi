import Foundation
import LumiCoreKit
import Testing
@testable import ToolCorePlugin

private func makeContext(allowed: [String] = []) -> LumiToolExecutionContext {
    LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "test",
        toolName: "read_file",
        allowedDirectories: allowed
    )
}

@Suite(.serialized)
final class ReadFileToolTests {
    private var tmpDir: URL!

    init() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ToolCorePlugin.read.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    @Test func readsFileWithOffsetAndLimit() async throws {
        let file = tmpDir.appendingPathComponent("test.txt")
        let content = (1...100).map { "Line \($0)" }.joined(separator: "\n")
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = ReadFileTool()
        let result = try await tool.execute(
            arguments: ["path": .string(file.path), "offset": .int(10), "limit": .int(5)],
            context: makeContext()
        )
        #expect(result.contains("Line 10"))
        #expect(result.contains("Line 14"))
        #expect(!result.contains("Line 15"))
    }

    @Test func readsFileWithNegativeOffset() async throws {
        let file = tmpDir.appendingPathComponent("negative.txt")
        let content = (1...10).map { "Line \($0)" }.joined(separator: "\n")
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = ReadFileTool()
        let result = try await tool.execute(
            arguments: ["path": .string(file.path), "offset": .int(-3)],
            context: makeContext()
        )
        #expect(result.contains("Line 8"))
        #expect(result.contains("Line 10"))
    }

    @Test func returnsEmptyForEmptyFile() async throws {
        let file = tmpDir.appendingPathComponent("empty.txt")
        try "".write(to: file, atomically: true, encoding: .utf8)

        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: ["path": .string(file.path)], context: makeContext())
        #expect(result == "")
    }

    @Test func returnsErrorForInvalidUTF8() async throws {
        let file = tmpDir.appendingPathComponent("binary.bin")
        try Data([0xFF, 0xFE, 0x80, 0x00]).write(to: file)

        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: ["path": .string(file.path)], context: makeContext())
        #expect(result.contains("UTF-8"))
    }

    @Test func returnsErrorForNonexistentFile() async throws {
        let tool = ReadFileTool()
        let result = try await tool.execute(
            arguments: ["path": .string("/tmp/nonexistent_\(UUID().uuidString).txt")],
            context: makeContext()
        )
        #expect(result.contains("Error"))
    }

    @Test func throwsWhenPathMissing() async throws {
        let tool = ReadFileTool()
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: [:], context: makeContext())
        }
    }

    @Test func throwsWhenPathDenied() async throws {
        let file = tmpDir.appendingPathComponent("denied.txt")
        try "data".write(to: file, atomically: true, encoding: .utf8)

        let tool = ReadFileTool()
        let denied = makeContext(allowed: ["/tmp/allowed_only"])
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: ["path": .string(file.path)], context: denied)
        }
    }

    @Test func displayDescriptionWithPathOnly() {
        let tool = ReadFileTool()
        let desc = tool.displayDescription(arguments: ["path": .string("/Users/angel/Code/test.swift")])
        #expect(desc.contains("test.swift"))
    }

    @Test func displayDescriptionWithOffsetAndLimit() {
        let tool = ReadFileTool()
        let desc = tool.displayDescription(arguments: [
            "path": .string("/Users/angel/Code/test.swift"),
            "offset": .int(10),
            "limit": .int(50)
        ])
        #expect(desc.contains("10"))
        #expect(desc.contains("50"))
    }

    @Test func displayDescriptionWithOffsetOnly() {
        let tool = ReadFileTool()
        let desc = tool.displayDescription(arguments: [
            "path": .string("/Users/angel/Code/test.swift"),
            "offset": .int(20)
        ])
        #expect(desc.contains("20"))
    }

    @Test func displayDescriptionFallbackWhenNoPath() {
        let tool = ReadFileTool()
        let desc = tool.displayDescription(arguments: [:])
        #expect(desc.contains("读取文件"))
    }

    @Test func riskLevelIsLow() {
        let tool = ReadFileTool()
        #expect(tool.riskLevel(arguments: [:], context: nil) == .low)
    }

    @Test func acceptsDoubleAsIntArgument() async throws {
        let file = tmpDir.appendingPathComponent("double.txt")
        let content = (1...20).map { "Line \($0)" }.joined(separator: "\n")
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = ReadFileTool()
        let result = try await tool.execute(
            arguments: ["path": .string(file.path), "offset": .double(5.0), "limit": .double(3.0)],
            context: makeContext()
        )
        #expect(result.contains("Line 5"))
    }
}
