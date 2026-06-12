import LumiCoreKit
import ProjectsPlugin
import Testing
import Foundation

@MainActor
@Test func projectsPluginContributesCenterToolbarItem() {
    let store = LumiCurrentProjectPathStore()
    let context = LumiPluginContext(
        activeSectionID: "editor",
        activeSectionTitle: "Editor",
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiCurrentProjectPathStoring.self, store)
        }
    )
    let items = ProjectsPlugin.titleToolbarItems(context: context)

    #expect(items.count == 1)
    #expect(items.first?.id == "com.coffic.lumi.plugin.projects.toolbar")
    #expect(items.first?.placement == .center)
}

@MainActor
@Test func projectsPluginContributesConversationHintMiddleware() {
    let context = LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
    #expect(ProjectsPlugin.sendMiddlewares(context: context).count == 1)
}

@MainActor
@Test func projectsPluginContributesProjectTools() async throws {
    let dataRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("ProjectsPluginTests-\(UUID().uuidString)", isDirectory: true)
    let projectDirectory = dataRoot
        .appendingPathComponent("SampleProject", isDirectory: true)
    try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
    LumiCore.configure(dataRootDirectory: dataRoot)

    let context = LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
    let tools = ProjectsPlugin.agentTools(context: context)

    #expect(tools.map(\.name).contains("add_project"))
    #expect(tools.map(\.name).contains("list_projects"))
    #expect(tools.map(\.name).contains("get_current_project"))

    let toolContext = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "tool-call",
        toolName: "projects"
    )

    let addTool = try #require(tools.first { $0.name == "add_project" })
    let addOutput = try await addTool.execute(
        arguments: ["path": .string(projectDirectory.path)],
        context: toolContext
    )
    #expect(addOutput.contains("SampleProject"))

    let listTool = try #require(tools.first { $0.name == "list_projects" })
    let listOutput = try await listTool.execute(arguments: [:], context: toolContext)
    #expect(listOutput.contains("SampleProject"))
    #expect(listOutput.contains(projectDirectory.path))

    let currentTool = try #require(tools.first { $0.name == "get_current_project" })
    let currentOutput = try await currentTool.execute(arguments: [:], context: toolContext)
    #expect(currentOutput.contains("SampleProject"))
}
