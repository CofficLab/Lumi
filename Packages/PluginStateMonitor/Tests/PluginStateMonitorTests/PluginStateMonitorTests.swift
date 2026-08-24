import Testing
import KernelCore
import ProviderConversation
import ProviderProject
@testable import PluginStateMonitor

@MainActor
@Test func projectPathsAreNormalizedBeforeComparison() {
    #expect(StateMonitorPlugin.normalized("/tmp/one/../two") == "/tmp/two")
    #expect(StateMonitorPlugin.normalized("") == nil)
    #expect(StateMonitorPlugin.normalized(nil) == nil)
}

@MainActor
@Test func selectingConversationFollowsItsProjectAndExternalProjectChangeClearsSelection() async throws {
    let kernel = KernelCoreContainer()
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProviding()
    try kernel.registerProvider((any ConversationManaging).self, conversations)
    try kernel.registerProvider((any ProjectProviding).self, project)

    let plugin = StateMonitorPlugin()
    try plugin.onReady(kernel: kernel)
    _ = try conversations.createConversation(
        title: "Project-bound",
        projectPath: "/tmp/state-monitor-project",
        providerID: nil,
        modelName: nil
    )
    for _ in 0..<10 { await Task.yield() }
    #expect(project.currentProject?.path == "/tmp/state-monitor-project")

    try await project.openProject(at: "/tmp/another-project")
    for _ in 0..<10 { await Task.yield() }
    #expect(conversations.selectedConversationID == nil)
    try plugin.onShutdown(kernel: kernel)
}
