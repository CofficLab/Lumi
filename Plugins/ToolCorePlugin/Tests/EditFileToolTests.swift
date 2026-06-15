import Foundation
import LumiCoreKit
import Testing
@testable import ToolCorePlugin

private func makeContext(allowed: [String] = []) -> LumiToolExecutionContext {
    LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "test",
        toolName: "edit_file",
        allowedDirectories: allowed
    )
}

@Suite(.serialized)
final class EditFileToolTests {
    private var tmpDir: URL!

    init() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ToolCorePlugin.edit.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    @Test func replaceSingleOccurrence() async throws {
        let file = tmpDir.appendingPathComponent("test.txt")
        try "Hello, World!".write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        let result = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string("World"),
                "new_string": .string("Swift")
            ],
            context: makeContext()
        )

        #expect(result.contains("updated"))
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "Hello, Swift!")
    }

    @Test func replaceAllOccurrences() async throws {
        let file = tmpDir.appendingPathComponent("multi.txt")
        try "foo bar foo bar foo".write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        let result = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string("foo"),
                "new_string": .string("baz"),
                "replace_all": .bool(true)
            ],
            context: makeContext()
        )

        #expect(result.contains("3"))
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "baz bar baz bar baz")
    }

    @Test func throwsWhenOldStringNotFound() async throws {
        let file = tmpDir.appendingPathComponent("nomatch.txt")
        try "Hello, World!".write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(
                arguments: [
                    "file_path": .string(file.path),
                    "old_string": .string("NotExist"),
                    "new_string": .string("Swift")
                ],
                context: makeContext()
            )
        }
    }

    @Test func throwsWhenPathMissing() async throws {
        let tool = EditFileTool()
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(
                arguments: ["old_string": .string("a"), "new_string": .string("b")],
                context: makeContext()
            )
        }
    }

    @Test func throwsWhenOldStringMissing() async throws {
        let file = tmpDir.appendingPathComponent("file.txt")
        let tool = EditFileTool()
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(
                arguments: ["file_path": .string(file.path), "new_string": .string("b")],
                context: makeContext()
            )
        }
    }

    @Test func throwsWhenNewStringMissing() async throws {
        let file = tmpDir.appendingPathComponent("file.txt")
        let tool = EditFileTool()
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(
                arguments: ["file_path": .string(file.path), "old_string": .string("a")],
                context: makeContext()
            )
        }
    }

    @Test func throwsWhenPathDenied() async throws {
        let file = tmpDir.appendingPathComponent("denied.txt")
        let tool = EditFileTool()
        let denied = makeContext(allowed: ["/tmp/allowed_only"])
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(
                arguments: [
                    "file_path": .string(file.path),
                    "old_string": .string("a"),
                    "new_string": .string("b")
                ],
                context: denied
            )
        }
    }

    @Test func displayDescriptionShowsFilename() {
        let tool = EditFileTool()
        let desc = tool.displayDescription(arguments: ["file_path": .string("/Users/angel/Code/test.swift")])
        #expect(desc.contains("test.swift"))
    }

    @Test func displayDescriptionFallbackWhenNoPath() {
        let tool = EditFileTool()
        let desc = tool.displayDescription(arguments: [:])
        #expect(desc.contains("Edit file"))
    }

    @Test func riskLevelIsHigh() {
        let tool = EditFileTool()
        #expect(tool.riskLevel(arguments: [:], context: nil) == .high)
    }

    @Test func replaceWithEmptyString() async throws {
        let file = tmpDir.appendingPathComponent("remove.txt")
        try "Hello, World!".write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        _ = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string(", World"),
                "new_string": .string("")
            ],
            context: makeContext()
        )

        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "Hello!")
    }
}
