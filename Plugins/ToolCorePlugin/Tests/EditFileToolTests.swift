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

    // MARK: - Bug Reproduction Tests

    /// 测试文件中有多个相同字符串时的编辑行为
    /// 这是为了复现 edit_file 的 bug：两个位置的字符串匹配不一致导致内容重复
    @Test func replaceDuplicateStringsInFile() async throws {
        let file = tmpDir.appendingPathComponent("duplicate.swift")
        // 文件内容：两个相同的代码块
        // 原始有 3 个 { : func start(), timer = Timer.scheduledTimer {..., func stop()
        let content = """
        func start() {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                doSomething()
            }
        }

        func stop() {
            timer?.invalidate()
        }
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        _ = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string("timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in"),
                "new_string": .string("let timer = Timer(timeInterval: 1.0, repeats: true) { _ in")
            ],
            context: makeContext()
        )

        let result = try String(contentsOf: file, encoding: .utf8)

        // 验证：编辑后仍应有 3 个 {（两个函数声明 + 一个闭包）
        // 修复前会导致内容重复，增加 { 的数量
        #expect(result.filter { $0 == "{" }.count == 3, "Should have exactly 3 opening braces after edit")
    }

    /// 测试包含重复代码行的文件（如 Swift 代码中有多处相同的属性声明）
    /// 验证：当有多个匹配项但 replace_all=false 时，应抛出错误要求用户明确指定
    @Test func replaceDuplicateMethodDeclarations() async throws {
        let file = tmpDir.appendingPathComponent("methods.swift")
        let content = """
        class Foo {
            var value: Int = 0
            var value: Int = 0
            var value: Int = 0
        }
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        
        // 当有 3 个匹配项时，应该报错，要求用户使用 replace_all=true 或提供更多上下文
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(
                arguments: [
                    "file_path": .string(file.path),
                    "old_string": .string("var value: Int = 0"),
                    "new_string": .string("let computed: Bool"),
                    "replace_all": .bool(false)
                ],
                context: makeContext()
            )
        }
    }
    
    /// 测试使用 replace_all=true 替换所有重复项
    @Test func replaceAllDuplicateDeclarations() async throws {
        let file = tmpDir.appendingPathComponent("replace_all.swift")
        let content = """
        class Foo {
            var value: Int = 0
            var value: Int = 0
            var value: Int = 0
        }
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        _ = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string("var value: Int = 0"),
                "new_string": .string("let computed: Bool"),
                "replace_all": .bool(true)
            ],
            context: makeContext()
        )

        let result = try String(contentsOf: file, encoding: .utf8)
        
        // 所有 "var value" 都被替换为 "let computed"
        #expect(result.contains("let computed: Bool"))
        #expect(!result.contains("var value"))
    }
}
