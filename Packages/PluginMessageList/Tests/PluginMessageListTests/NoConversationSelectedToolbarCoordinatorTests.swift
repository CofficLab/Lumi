import ProviderProject
import ProviderToolbar
import Testing
@testable import PluginMessageList

@Suite("NoConversationSelectedToolbarCoordinator")
@MainActor
struct NoConversationSelectedToolbarCoordinatorTests {
    @Test("无项目时隐藏项目分类，添加项目后恢复")
    func hidesProjectCategoryOnlyWhileProjectListIsEmpty() {
        let project = DefaultProjectProvider()
        let toolbar = DefaultToolbarProviding()
        toolbar.setVisibleCategories([.global, .chat, .project])
        let coordinator = NoConversationSelectedToolbarCoordinator(project: project, toolbar: toolbar)
        let projectObserver = project.addObserver { _ in coordinator.refresh() }
        defer { projectObserver.cancel() }

        coordinator.activate()
        #expect(toolbar.visibleCategories == [.global, .chat])

        project.synchronizeProjects([
            ProjectInfo(name: "Lumi", path: "/tmp/Lumi"),
        ])
        #expect(toolbar.visibleCategories == [.global, .chat, .project])

        project.synchronizeProjects([])
        #expect(toolbar.visibleCategories == [.global, .chat])

        coordinator.deactivate()
        #expect(toolbar.visibleCategories == [.global, .chat, .project])
    }
}
