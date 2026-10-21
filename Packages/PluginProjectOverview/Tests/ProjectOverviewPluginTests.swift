import Foundation
import KernelCore
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
