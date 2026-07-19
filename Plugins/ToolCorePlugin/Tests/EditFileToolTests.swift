import Foundation
import LumiKernel
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
        #expect(desc.contains("编辑文件"))
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

    // MARK: - File Content Duplication Bug Reproduction

    /// 复现用户报告的 bug：在 ~800 行的 Swift 文件中插入 @State 变量，
    /// 导致文件内容大面积重复。
    ///
    /// 场景：NodeView.swift 约 812 行，用户想在第 101-102 行附近插入：
    ///   @State private var cachedBatchActionURLs: [URL] = []
    ///
    /// old_string 是 101-102 行附近的空行。
    /// 预期：只插入 3 行。实际（bug）：文件内容被大面积重复。
    @Test func insertStateVariableBetweenCodeBlocks_noDuplication() async throws {
        let file = tmpDir.appendingPathComponent("NodeView.swift")

        // 模拟一个包含多个属性、方法、MARK 注释的 Swift 视图文件
        let originalContent = """
        import SwiftUI

        struct NodeView: View {
            // MARK: - Properties

            @State private var isExpanded: Bool = false
            @State private var isLoading: Bool = false
            @State private var errorMessage: String?

            var node: TreeNode
            var depth: Int

            // MARK: - Body

            var body: some View {
                HStack {
                    Toggle(isOn: $isExpanded) {
                        Text(node.title)
                    }
                    if isLoading {
                        ProgressView()
                    }
                }
            }

            // MARK: - Actions

            private func toggleNode() {
                isExpanded.toggle()
            }

            private func loadChildren() async {
                do {
                    try await node.fetchChildren()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }

            // MARK: - Helpers

            private func formatTitle(_ title: String) -> String {
                return title.trimmingCharacters(in: .whitespaces)
            }

            private func nodeColor(for status: NodeStatus) -> Color {
                switch status {
                case .active: return .green
                case .inactive: return .red
                case .pending: return .yellow
                }
            }
        }
        """
        try originalContent.write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        let result = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string("""
        @State private var errorMessage: String?

        var node: TreeNode
"""),
                "new_string": .string("""
        @State private var errorMessage: String?
        @State private var cachedBatchActionURLs: [URL] = []

        var node: TreeNode
"""),
                "replace_all": .bool(false)
            ],
            context: makeContext()
        )

        let finalContent = try String(contentsOf: file, encoding: .utf8)

        // 核心断言：文件不应有内容重复
        // 原始有 4 个 "// MARK:" 注释，编辑后仍应有 4 个
        let originalMarkCount = originalContent.components(separatedBy: "// MARK:").count - 1
        let finalMarkCount = finalContent.components(separatedBy: "// MARK:").count - 1
        #expect(finalMarkCount == originalMarkCount,
                "MARK comments should not be duplicated. Expected \(originalMarkCount), got \(finalMarkCount)")

        // 原始有 3 个 "private func" 声明，编辑后仍应有 3 个
        let originalFuncCount = originalContent.components(separatedBy: "private func").count - 1
        let finalFuncCount = finalContent.components(separatedBy: "private func").count - 1
        #expect(finalFuncCount == originalFuncCount,
                "Function declarations should not be duplicated. Expected \(originalFuncCount), got \(finalFuncCount)")

        // 文件行数应该只增加 1 行（新插入的 @State 行）
        let originalLineCount = originalContent.components(separatedBy: "\n").count
        let finalLineCount = finalContent.components(separatedBy: "\n").count
        #expect(finalLineCount == originalLineCount + 1,
                "Line count should increase by exactly 1. Expected \(originalLineCount + 1), got \(finalLineCount)")

        // 新变量应该被正确插入
        #expect(finalContent.contains("@State private var cachedBatchActionURLs: [URL] = []"),
                "New @State variable should be present in file")

        // 原始内容应该完整保留
        #expect(finalContent.contains("@State private var isExpanded: Bool = false"),
                "Original @State variables should be preserved")
        #expect(finalContent.contains("private func toggleNode()"),
                "Original methods should be preserved")
        #expect(finalContent.contains("private func formatTitle"),
                "Original helpers should be preserved")
    }

    /// 测试带有弯引号的文件编辑行为
    /// 验证 preserveQuoteStyle 不会导致内容重复
    @Test func editFileWithCurlyQuotes_noDuplication() async throws {
        let file = tmpDir.appendingPathComponent("quotes.swift")
        let content = """
        // This is a comment with "curly quotes" in it
        // Another comment with "more quotes" here

        struct QuotedView: View {
            let title: String

            var body: some View {
                Text(title)
            }
        }
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        _ = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string("let title: String"),
                "new_string": .string("let title: String\n    @State private var isHovered = false"),
                "replace_all": .bool(false)
            ],
            context: makeContext()
        )

        let result = try String(contentsOf: file, encoding: .utf8)

        // 验证弯引号评论没有被破坏
        #expect(result.contains("curly quotes"), "Comment with curly quotes should be preserved")
        #expect(result.contains("more quotes"), "Second quote comment should be preserved")

        // 验证没有内容重复
        let originalStructCount = content.components(separatedBy: "struct QuotedView").count - 1
        let finalStructCount = result.components(separatedBy: "struct QuotedView").count - 1
        #expect(finalStructCount == originalStructCount, "Struct should appear exactly once")
    }

    /// 测试 CRLF 行尾文件的编辑行为
    /// 验证 adaptReplacementLineEndings 不会导致内容重复
    @Test func editFileWithCRLF_noDuplication() async throws {
        let file = tmpDir.appendingPathComponent("crlf.swift")
        // 使用 CRLF 行尾
        let content = "struct CRLFView: View {\r\n    let title: String\r\n\r\n    var body: some View {\r\n        Text(title)\r\n    }\r\n}"
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        _ = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string("let title: String\r\n"),
                "new_string": .string("let title: String\n    @State private var isExpanded = false\n"),
                "replace_all": .bool(false)
            ],
            context: makeContext()
        )

        let result = try String(contentsOf: file, encoding: .utf8)

        // 验证结构仍然正确
        #expect(result.contains("struct CRLFView"), "Struct declaration should be preserved")
        #expect(result.contains("var body: some View"), "Body declaration should be preserved")

        // 验证没有内容重复
        let originalStructCount = content.components(separatedBy: "struct CRLFView").count - 1
        let finalStructCount = result.components(separatedBy: "struct CRLFView").count - 1
        #expect(finalStructCount == originalStructCount, "Struct should appear exactly once")
    }

    /// 测试 old_string 唯一且 replace_all=false 时，只替换一次
    @Test func uniqueOldString_replacesOnlyOnce() async throws {
        let file = tmpDir.appendingPathComponent("unique.swift")
        let content = """
        // Header
        class UniqueClass {
            var first: String
            var second: String
            var third: String

            func doSomething() {
                print("done")
            }
        }
        // Footer
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        _ = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string("var second: String"),
                "new_string": .string("var second: Int"),
                "replace_all": .bool(false)
            ],
            context: makeContext()
        )

        let result = try String(contentsOf: file, encoding: .utf8)

        // 只有 second 被替换
        #expect(result.contains("var first: String"))
        #expect(result.contains("var second: Int"))
        #expect(result.contains("var third: String"))

        // 类声明只出现一次
        let classCount = result.components(separatedBy: "class UniqueClass").count - 1
        #expect(classCount == 1, "Class should appear exactly once, got \(classCount)")

        // 方法只出现一次
        let methodCount = result.components(separatedBy: "func doSomething").count - 1
        #expect(methodCount == 1, "Method should appear exactly once, got \(methodCount)")
    }

    /// 测试重复编辑检测：当 new_string 中的新内容已经存在于文件中时，应拒绝编辑
    @Test func detectsDuplicateEdit() async throws {
        let file = tmpDir.appendingPathComponent("dup_detect.swift")
        // 文件已经包含了 @State private var cachedBatchActionURLs: [URL] = []
        let content = """
        import SwiftUI

        struct NodeView: View {
            @State private var isExpanded: Bool = false
            @State private var errorMessage: String?
            @State private var cachedBatchActionURLs: [URL] = []

            var node: TreeNode
        }
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        // 尝试重复插入同一行（基于过时的上下文）
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(
                arguments: [
                    "file_path": .string(file.path),
                    "old_string": .string("@State private var errorMessage: String?\n\n            var node: TreeNode"),
                    "new_string": .string("@State private var errorMessage: String?\n            @State private var cachedBatchActionURLs: [URL] = []\n\n            var node: TreeNode"),
                    "replace_all": .bool(false)
                ],
                context: makeContext()
            )
        }

        // 验证文件内容未被修改
        let result = try String(contentsOf: file, encoding: .utf8)
        #expect(result == content, "File should be unchanged after rejected edit")
    }

    /// 测试正常编辑：新内容不在文件中，应成功
    @Test func allowsFreshEdit() async throws {
        let file = tmpDir.appendingPathComponent("fresh_edit.swift")
        let content = """
        import SwiftUI

        struct NodeView: View {
            @State private var isExpanded: Bool = false
            @State private var errorMessage: String?

            var node: TreeNode
        }
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let tool = EditFileTool()
        let result = try await tool.execute(
            arguments: [
                "file_path": .string(file.path),
                "old_string": .string("@State private var errorMessage: String?\n\n            var node: TreeNode"),
                "new_string": .string("@State private var errorMessage: String?\n            @State private var cachedBatchActionURLs: [URL] = []\n\n            var node: TreeNode"),
                "replace_all": .bool(false)
            ],
            context: makeContext()
        )

        #expect(result.contains("updated"), "Edit should succeed")
        let finalContent = try String(contentsOf: file, encoding: .utf8)
        #expect(finalContent.contains("cachedBatchActionURLs"), "New variable should be present")
    }
}
