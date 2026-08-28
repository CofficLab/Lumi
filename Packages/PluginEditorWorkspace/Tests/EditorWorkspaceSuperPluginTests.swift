import Combine
import EditorContracts
import KernelCore
import PluginEditorHost
import PluginEditorWorkspace
import ProviderActivityBar
import ProviderContentView
import ProviderPluginControl
import ProviderProject
import ProviderRailView
import SwiftUI
import Testing

@MainActor
struct EditorWorkspaceSuperPluginTests {
    @Test("is user configurable and disabled by default")
    func metadata() {
        let plugin = EditorWorkspaceSuperPlugin()
        #expect(plugin.metadata.policy == .disabledByDefault)
        #expect(plugin.dependencies == ["com.coffic.lumi.plugin.editor-host"])
    }

    @Test("enabling and disabling installs and removes workspace contributions")
    func lifecycle() async throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let rail = DefaultRailViewProviding()
        let content = TestContentProvider()
        let project = TestLifecycleProjectProvider()
        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider((any RailViewProviding).self, rail)
        try kernel.registerProvider((any ContentViewProviding).self, content)
        try kernel.registerProvider((any ProjectProviding).self, project)
        let workspace = EditorWorkspaceSuperPlugin()
        try kernel.start(plugins: [EditorHostSuperPlugin(), workspace])
        let control = DefaultPluginControlling(kernel: kernel)

        #expect(activity.items.allSatisfy { $0.id != EditorWorkspaceSuperPlugin.activityItemID })
        #expect(await control.enablePlugin(id: workspace.id))
        #expect(activity.items.filter { $0.id == EditorWorkspaceSuperPlugin.activityItemID }.count == 1)
        #expect(rail.tabs.filter { $0.id == EditorWorkspaceSuperPlugin.explorerTabID }.count == 1)

        activity.activateItem(id: EditorWorkspaceSuperPlugin.activityItemID)
        #expect(rail.activeGroupID == workspace.id)
        #expect(content.setCount == 1)

        #expect(await control.disablePlugin(id: workspace.id))
        #expect(activity.items.allSatisfy { $0.id != EditorWorkspaceSuperPlugin.activityItemID })
        #expect(rail.tabs.allSatisfy { $0.id != EditorWorkspaceSuperPlugin.explorerTabID })
        #expect(content.clearCount == 1)

        #expect(await control.enablePlugin(id: workspace.id))
        #expect(activity.items.filter { $0.id == EditorWorkspaceSuperPlugin.activityItemID }.count == 1)
        #expect(rail.tabs.filter { $0.id == EditorWorkspaceSuperPlugin.explorerTabID }.count == 1)
    }
}

@MainActor
private final class TestContentProvider: ContentViewProviding {
    @Published private var revision = 0
    private(set) var setCount = 0
    private(set) var clearCount = 0

    func setContentView(_ view: AnyView?) {
        if view == nil { clearCount += 1 } else { setCount += 1 }
        revision += 1
    }

    func makeContentView() -> AnyView { AnyView(EmptyView()) }
}

@MainActor
private final class TestLifecycleProjectProvider: ProjectProviding {
    @Published var currentProject: ProjectInfo?
    @Published var openFileURLs: [URL] = []
    @Published var currentFileURL: URL?
    @Published var projects: [ProjectInfo] = []
    func openProject(at path: String) async throws {}
    func updateCurrentFile(_ fileURL: URL?) { currentFileURL = fileURL }
    func updateOpenFiles(_ fileURLs: [URL]) { openFileURLs = fileURLs }
    func closeFile(_ fileURL: URL) { openFileURLs.removeAll { $0 == fileURL } }
    func closeProject() async {}
    func refreshProjects() async throws {}
    func synchronizeProjects(_ projects: [ProjectInfo]) { self.projects = projects }
}
