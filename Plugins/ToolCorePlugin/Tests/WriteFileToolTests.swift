import Foundation
import LumiKernel
import Testing
@testable import ToolCorePlugin

private func makeContext(allowed: [String] = []) -> LumiToolExecutionContext {
    LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "test",
        toolName: "write_file",
        allowedDirectories: allowed
    )
}

@Suite(.serialized)
final class WriteFileToolTests {
    private var tmpDir: URL!

    init() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ToolCorePlugin.write.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    @Test func writesFileSuccessfully() async throws {
        let file = tmpDir.appendingPathComponent("output.txt")
        let tool = WriteFileTool()
        let result = try await tool.execute(
            arguments: ["path": .string(file.path), "content": .string("Hello, World!")],
            context: makeContext()
        )

        #expect(result.contains("13"))
        #expect(result.contains(file.path))

        let written = try String(contentsOf: file, encoding: .utf8)
        #expect(written == "Hello, World!")
    }

    @Test func createsParentDirectoryAutomatically() async throws {
        let nested = tmpDir.appendingPathComponent("deep/nested/dir/file.txt")
        let tool = WriteFileTool()
        _ = try await tool.execute(
            arguments: ["path": .string(nested.path), "content": .string("nested content")],
            context: makeContext()
        )

        let written = try String(contentsOf: nested, encoding: .utf8)
        #expect(written == "nested content")
    }

    @Test func overwritesExistingFile() async throws {
        let file = tmpDir.appendingPathComponent("existing.txt")
        try "original".write(to: file, atomically: true, encoding: .utf8)

        let tool = WriteFileTool()
        _ = try await tool.execute(
            arguments: ["path": .string(file.path), "content": .string("updated")],
            context: makeContext()
        )

        let written = try String(contentsOf: file, encoding: .utf8)
        #expect(written == "updated")
    }

    @Test func throwsWhenPathMissing() async throws {
        let tool = WriteFileTool()
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: ["content": .string("data")], context: makeContext())
        }
    }

    @Test func throwsWhenContentMissing() async throws {
        let file = tmpDir.appendingPathComponent("file.txt")
        let tool = WriteFileTool()
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: ["path": .string(file.path)], context: makeContext())
        }
    }

    @Test func throwsWhenPathDenied() async throws {
        let file = tmpDir.appendingPathComponent("denied.txt")
        let tool = WriteFileTool()
        let denied = makeContext(allowed: ["/tmp/allowed_only"])
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(
                arguments: ["path": .string(file.path), "content": .string("data")],
                context: denied
            )
        }
    }

    @Test func displayDescriptionShowsFilename() {
        let tool = WriteFileTool()
        let desc = tool.displayDescription(arguments: ["path": .string("/Users/angel/Code/test.txt")])
        #expect(desc.contains("test.txt"))
    }

    @Test func displayDescriptionFallbackWhenNoPath() {
        let tool = WriteFileTool()
        let desc = tool.displayDescription(arguments: [:])
        #expect(desc.contains("写入文件"))
    }

    @Test func riskLevelIsMedium() {
        let tool = WriteFileTool()
        #expect(tool.riskLevel(arguments: [:], context: nil) == .medium)
    }

    @Test func handlesEmptyContent() async throws {
        let file = tmpDir.appendingPathComponent("empty.txt")
        let tool = WriteFileTool()
        let result = try await tool.execute(
            arguments: ["path": .string(file.path), "content": .string("")],
            context: makeContext()
        )

        #expect(result.contains("0"))
        let written = try String(contentsOf: file, encoding: .utf8)
        #expect(written == "")
    }
}
