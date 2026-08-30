import KernelCore
import ProviderProject
import ProviderRailView
import Testing

@testable import PluginProjectFileTree

@MainActor
@Test("文件树仅在存在当前项目时显示 Explorer")
func explorerTabFollowsCurrentProject() async throws {
    let kernel = KernelCoreContainer()
    let project = DefaultProjectProvider()
    let railView = DefaultRailViewProviding()
    try kernel.registerProvider((any ProjectProviding).self, project)
    try kernel.registerProvider((any RailViewProviding).self, railView)

    let plugin = ProjectFileTreePlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(railView.tabs.isEmpty)

    try await project.openProject(at: "/tmp/lumi-file-tree-test-project")
    #expect(railView.tabs.map(\.id) == [ProjectFileTreePlugin.railTabID])

    await project.closeProject()
    #expect(railView.tabs.isEmpty)

    try plugin.onShutdown(kernel: kernel)
}
