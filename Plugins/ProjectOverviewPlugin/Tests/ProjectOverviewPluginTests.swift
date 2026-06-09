import Foundation
import AgentToolKit
import LumiCoreKit
import Testing
@testable import ProjectOverviewPlugin

@Suite("PluginProjectOverview")
struct PluginProjectOverviewTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(ProjectOverviewPlugin.id == "ProjectOverview")
        #expect(ProjectOverviewPlugin.displayName == "Project Overview")
        #expect(ProjectOverviewPlugin.iconName == "doc.text.magnifyingglass")
        #expect(ProjectOverviewPlugin.category == .general)
        #expect(ProjectOverviewPlugin.order == 14)
        #expect(ProjectOverviewPlugin.isConfigurable == false)
    }

    @MainActor
    @Test("plugin registers one tool")
    func pluginRegistersTool() {
        let tools = ProjectOverviewPlugin.agentTools(
            context: LumiPluginContext(activeSectionID: "test", activeSectionTitle: "Test")
        )

        #expect(tools.count == 1)
        #expect(tools.first?.name == "project_overview")
    }

    @Test("tool name and description")
    func toolMetadata() {
        let tool = ProjectOverviewTool()
        #expect(tool.name == "project_overview")

        let enDesc = tool.description(for: .english)
        #expect(enDesc.contains("project overview"))

        let zhDesc = tool.description(for: .chinese)
        #expect(zhDesc.contains("项目概览"))
    }

    @Test("tool input schema")
    func toolInputSchema() throws {
        let tool = ProjectOverviewTool()
        let schema = tool.inputSchema(for: .english)

        let properties = try #require(schema["properties"] as? [String: Any])
        #expect(properties["path"] != nil)
    }

    @Test("tool risk level is low")
    func toolRiskLevel() {
        let tool = ProjectOverviewTool()
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

        // 创建 README.md
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
        #expect(PluginProjectOverviewLocalization.bundle.url(forResource: "ProjectOverview", withExtension: "xcstrings") != nil)
        #expect(PluginProjectOverviewLocalization.string("Project Overview").isEmpty == false)
    }
}
