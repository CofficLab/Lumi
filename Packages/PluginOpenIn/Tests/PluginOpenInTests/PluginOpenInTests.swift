import Combine
import Foundation
import Testing
import KernelCore
import AgentToolKit
import ProviderProject
import ProviderToolManager

@testable import PluginOpenIn

@Suite("OpenInPlugin")
@MainActor
struct OpenInPluginTests {
    /// 内存 ProjectProviding stub。
    @MainActor
    private final class StubProject: ProjectProviding {
        var currentProject: ProjectInfo?
        var projects: [ProjectInfo] = []
        @Published var tick = false
        init(path: String?) {
            currentProject = path.map { ProjectInfo(name: "test", path: $0) }
        }
        func openProject(at path: String) async throws {}
        func closeProject() async {}
        func refreshProjects() async throws {}
    }

    @Test("工具名与描述正确")
    func toolMetadata() {
        let tool = OpenInTool(config: OpenInApps.xcode, project: nil)
        #expect(tool.name == "open_in_xcode")
        #expect(tool.description(for: .chinese).contains("Xcode"))
        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
    }

    @Test("displayDescription 使用传入路径")
    func displayDescriptionUsesPath() {
        let tool = OpenInTool(config: OpenInApps.finder, project: nil)
        let desc = tool.displayDescription(for: ["path": ToolArgument("/tmp/foo")])
        #expect(desc.contains("Finder"))
        #expect(desc.contains("/tmp/foo"))
    }

    @Test("无项目且无路径时返回错误")
    func missingPathError() async throws {
        let tool = OpenInTool(config: OpenInApps.finder, project: nil)
        let result = try await tool.execute(arguments: [:])
        #expect(result.contains("❌"))
    }

    @Test("插件注册全部 7 个工具")
    func pluginRegistersAllTools() throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let project = StubProject(path: "/tmp/proj")
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any ProjectProviding).self, project)

        let plugin = OpenInPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(toolManager.tool(named: "open_in_finder") != nil)
        #expect(toolManager.tool(named: "open_in_xcode") != nil)
        #expect(toolManager.tool(named: "open_in_cursor") != nil)
        #expect(toolManager.tool(named: "open_in_vscode") != nil)
        #expect(toolManager.tool(named: "open_in_antigravity") != nil)
        #expect(toolManager.tool(named: "open_in_github_desktop") != nil)
        #expect(toolManager.tool(named: "open_in_gitok") != nil)

        try plugin.onShutdown(kernel: kernel)
        #expect(toolManager.tool(named: "open_in_finder") == nil)
    }
}
