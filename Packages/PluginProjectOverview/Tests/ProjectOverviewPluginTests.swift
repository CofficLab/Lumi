import Foundation
import KernelCore
import KitAgentTool
import ProviderProject
import ProviderPromptSuggestion
import ProviderToolManager
import Testing
@testable import ProjectOverviewPlugin

@Suite("PluginProjectOverview")
@MainActor
struct PluginProjectOverviewTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(ProjectOverviewPlugin().id == "ProjectOverview")
        #expect(ProjectOverviewPlugin().metadata.name == "Project Overview")
        #expect(ProjectOverviewPlugin().order == 14)
        #expect(ProjectOverviewPlugin().metadata.policy == .alwaysOn)
    }

    /// 插件启动后应把工具注册到共享的 `ToolManagerProviding`。
    @Test("plugin registers one tool on boot")
    func pluginRegistersTool() throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)

        try ProjectOverviewPlugin().onBoot(kernel: kernel)

        let tools = toolManager.allTools()
        #expect(tools.count == 1)
        #expect(tools.first?.name == "project_overview")
        #expect(toolManager.tool(named: "project_overview") != nil)
    }

    /// 提示建议应注册到共享的 `PromptSuggestionProviding`，且仅在有项目时可见。
    @Test("prompt suggestion requires a project")
    func promptSuggestionRequiresProject() throws {
        let kernel = KernelCoreContainer()
        let suggestions = DefaultPromptSuggestionProvider()
        try kernel.registerProvider((any PromptSuggestionProviding).self, suggestions)

        try ProjectOverviewPlugin().onRegister(kernel: kernel)

        #expect(suggestions.allSuggestions.count == 1)
        let suggestion = try #require(suggestions.allSuggestions.first)
        #expect(suggestion.visibility == .onlyWithProject)
    }

    @Test("tool name and description")
    func toolMetadata() {
        let tool = ProjectOverviewV2Tool()
        #expect(tool.name == "project_overview")
        #expect(tool.description(for: .english).lowercased().contains("project overview"))
    }

    @Test("tool input schema")
    func toolInputSchema() {
        let tool = ProjectOverviewV2Tool()
        let schema = tool.inputSchema(for: .english)

        #expect(schema["type"] as? String == "object")
        guard let properties = schema["properties"] as? [String: Any] else {
            Issue.record("schema should declare properties object")
            return
        }
        #expect(properties["path"] != nil)
        #expect(schema["additionalProperties"] as? Bool == false)
    }

    @Test("tool risk level is low")
    func toolRiskLevel() {
        let tool = ProjectOverviewV2Tool()
        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
    }

    @Test("ProjectTypeSection detects Swift project")
    func projectTypeDetectsSwift() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_swift_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 创建 Package.swift
        try? "import PackageDescription\nlet package = Package(name: \"Test\")".write(to: tempDir.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let result = ProjectTypeSection.render(at: tempDir)
        #expect(result.contains("Swift"))

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("KeyFilesSection detects README")
    func keyFilesDetectsReadme() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_readme_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        try? "# Test".write(to: tempDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let result = KeyFilesSection.render(at: tempDir)
        #expect(result.contains("README: README.md"))

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("GitSection handles non-git directory")
    func gitSectionHandlesNonGit() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_nongit_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let result = GitSection.render(at: tempDir)
        #expect(result == "Not a Git repository.")

        try? FileManager.default.removeItem(at: tempDir)
    }

    /// 回归 #978：传入仓库子目录时，GitSection 只检查 `子目录/.git` 就直接返回
    /// "Not a Git repository."，而 Git 本身能向祖先目录发现工作树。
    @Test("GitSection detects the enclosing worktree from a subdirectory")
    func gitSectionDetectsEnclosingWorktree() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_git_subdir_\(UUID().uuidString)", isDirectory: true)
        let subdirectory = root.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = URL(fileURLWithPath: "/usr/bin/git")
        let process = Process()
        process.executableURL = git
        process.arguments = ["init", "-q", root.path]
        process.standardError = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)

        try "let value = 1\n".write(
            to: subdirectory.appendingPathComponent("Untracked.swift"),
            atomically: true,
            encoding: .utf8
        )

        let result = GitSection.render(at: subdirectory)

        #expect(result.contains("Repository: Yes"))
        #expect(result.contains("Status: Uncommitted changes"))
        #expect(!result.contains("Not a Git repository."))
    }

    /// 回归 #979：2,000 字节读取块恰好结束在完整 UTF-8 字符边界时，`text.count`
    /// 与 `preview.count` 都是 500，旧逻辑因此漏掉省略标记。
    @Test("README preview marks content beyond the byte cap")
    func readmePreviewMarksContentBeyondByteCap() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_readme_truncated_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // 501 个 emoji：2000 字节正好是 500 个完整字符，第 501 个字符未读。
        let readme = String(repeating: "😀", count: 501)
        try readme.write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let preview = ReadmePreviewSection.render(at: root)

        #expect(preview.hasSuffix("\n..."))
        #expect(preview.filter { $0 == "😀" }.count == 500)
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        let bundle = pluginLocalization.bundle
        // `.xcstrings` 是**源**目录里的文件；SPM 打包时会被编译成各语言的
        // `Localizable.strings`（`<lang>.lproj/Localizable.strings`），
        // 原始 `.xcstrings` 不会进 bundle。只查 `.xcstrings` 恒为 nil。
        let hasCatalog = bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil
        let hasCompiledStrings = bundle.path(forResource: "zh-Hans", ofType: "lproj") != nil
        #expect(hasCatalog || hasCompiledStrings)
        #expect(pluginLocalization.string("Project Overview").isEmpty == false)
    }
}

/// 工具必须按调用所属会话的项目读取，而不是 UI 当前打开的项目。
@Suite("ProjectOverviewConversationScope")
@MainActor
struct ProjectOverviewConversationScopeTests {

    private func makeProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-scope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "// swift-tools-version: 6.0\nimport PackageDescription\nlet package = Package(name: \"Scope\")"
            .write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        return root
    }

    private func path(in content: String) -> String {
        content
            .split(separator: "\n")
            .first { $0.hasPrefix("**Path**: ") }
            .map { String($0.dropFirst("**Path**: ".count)) } ?? ""
    }

    private func makeContext(projectPath: String?) -> ToolExecutionContext {
        ToolExecutionContext(
            jobID: UUID().uuidString,
            conversationID: UUID(),
            conversationProjectPathProvider: { projectPath }
        )
    }

    @Test("未传 path 时读取会话绑定项目，而不是 UI 当前项目")
    func usesConversationProject() async throws {
        let projectA = try makeProject()
        let projectB = try makeProject()
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }
        let provider = DefaultProjectProvider()
        try await provider.openProject(at: projectB.path)
        let tool = ProjectOverviewV2Tool(project: provider)

        let result = try await tool.executeResult(
            context: makeContext(projectPath: projectA.path),
            arguments: [:]
        )

        #expect(path(in: result.content) == projectA.standardizedFileURL.path)
        #expect(!result.content.contains(projectB.standardizedFileURL.path))
    }

    @Test("显式 path 优先于会话绑定项目")
    func explicitPathWins() async throws {
        let projectA = try makeProject()
        let projectB = try makeProject()
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }
        let tool = ProjectOverviewV2Tool(project: nil)

        let result = try await tool.executeResult(
            context: makeContext(projectPath: projectA.path),
            arguments: ["path": ToolArgument(projectB.path)]
        )

        #expect(path(in: result.content) == projectB.standardizedFileURL.path)
    }

    /// 回归：路径不存在曾经返回 "Error: ..." 字符串，默认 `executeResult`
    /// 会把它当成成功结果。
    @Test("路径不存在时抛出而不是返回错误字符串")
    func missingPathThrows() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-missing-\(UUID().uuidString)", isDirectory: true)
        let tool = ProjectOverviewV2Tool(project: nil)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(
                context: makeContext(projectPath: nil),
                arguments: ["path": ToolArgument(missing.path)]
            )
        }
    }
}
