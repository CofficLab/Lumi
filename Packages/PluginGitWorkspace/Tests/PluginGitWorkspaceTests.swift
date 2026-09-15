import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import Testing
@testable import PluginGitWorkspace

@MainActor
@Test("Git workspace plugin registers an ActivityBar entry")
func gitWorkspacePluginRegistersEntry() throws {
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any ActivityBarProviding).self, DefaultActivityBarProviding())
    try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
    try kernel.registerProvider((any ProjectProviding).self, DefaultProjectProvider())
    try kernel.registerProvider((any RootViewProviding).self, DefaultRootViewProvider())
    try kernel.registerProvider((any ToolbarProviding).self, DefaultToolbarProviding())

    try GitWorkspacePlugin().onBoot(kernel: kernel)

    let activity = kernel.resolveProvider((any ActivityBarProviding).self)
    #expect(activity?.items.map(\.id) == ["com.coffic.lumi.plugin.git-workspace.entry"])
}

@MainActor
@Test("Git workspace activation restores host UI and clears its content override")
func gitWorkspaceActivationAndShutdownRestoreHostUI() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    let chat = DefaultChatSectionProviding()
    let content = DefaultContentViewProviding()
    let project = DefaultProjectProvider()
    let rail = DefaultRailViewProviding()
    let root = DefaultRootViewProvider()
    let toolbar = DefaultToolbarProviding()
    root.setRailView(rail.makeRailView())
    var contentChanges = 0
    let contentObserver = content.addContentViewObserver { _ in contentChanges += 1 }
    defer { contentObserver.cancel() }
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ContentViewProviding).self, content)
    try kernel.registerProvider((any ProjectProviding).self, project)
    try kernel.registerProvider((any RailViewProviding).self, rail)
    try kernel.registerProvider((any RootViewProviding).self, root)
    try kernel.registerProvider((any ToolbarProviding).self, toolbar)
    let plugin = GitWorkspacePlugin()
    try plugin.onBoot(kernel: kernel)

    let entryID = "com.coffic.lumi.plugin.git-workspace.entry"
    #expect(activityBar.activeItemID == entryID)
    #expect(toolbar.visibleCategories == [.global, .project])
    #expect(rail.visibleCategories == [.project])
    #expect(root.isContentHeaderViewHidden)
    #expect(!chat.isVisible)
    #expect(root.isRailViewVisible == false)
    #expect(contentChanges == 1)

    activityBar.activateItem(id: nil)
    #expect(toolbar.visibleCategories == Set(ToolbarItemCategory.allCases))
    #expect(rail.visibleCategories == Set(RailViewCategory.allCases))
    #expect(!root.isContentHeaderViewHidden)
    #expect(chat.isVisible)
    #expect(contentChanges == 2)

    activityBar.activateItem(id: entryID)
    try plugin.onShutdown(kernel: kernel)
    #expect(activityBar.items.isEmpty)
    #expect(toolbar.visibleCategories == Set(ToolbarItemCategory.allCases))
    #expect(rail.visibleCategories == Set(RailViewCategory.allCases))
    #expect(!root.isContentHeaderViewHidden)
    #expect(chat.isVisible)
    #expect(contentChanges == 5)
}
