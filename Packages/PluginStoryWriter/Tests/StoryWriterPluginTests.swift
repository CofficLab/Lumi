import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderRailView
import ProviderRootView
import Testing

@testable import StoryWriterPlugin

@MainActor
@Test func v2PluginPreservesWorkspaceAndToolCatalog() async throws {
    let plugin = StoryWriterSuperPlugin()
    let expectedTools: Set<String> = [
        "list_stories", "get_story", "create_story", "update_story", "delete_story",
        "list_chapters", "get_chapter", "create_chapter", "update_chapter", "delete_chapter",
        "import_markdown_as_chapter", "export_story_as_markdown",
    ]

    #expect(plugin.id == "com.coffic.lumi.plugin.story-writer")
    #expect(Set(StoryWriterV2Tool.all.map(\.name)) == expectedTools)
}

@MainActor
@Test("激活时仅显示故事创作自己的 RailView，停用后恢复")
func activationScopesRailView() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    let contentView = DefaultContentViewProviding()
    let railView = DefaultRailViewProviding()
    let rootView = DefaultRootViewProvider()
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any ContentViewProviding).self, contentView)
    try kernel.registerProvider((any RailViewProviding).self, railView)
    try kernel.registerProvider((any RootViewProviding).self, rootView)

    let plugin = StoryWriterSuperPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(railView.tabs.map(\.id) == [StoryWriterSuperPlugin.railTabID])
    #expect(activityBar.activeItemID == "\(plugin.id).entry")
    #expect(railView.visibleTabID == StoryWriterSuperPlugin.railTabID)
    #expect(railView.activeTabID == StoryWriterSuperPlugin.railTabID)
    #expect(rootView.isContentHeaderViewHidden)

    activityBar.activateItem(id: nil)

    #expect(railView.visibleCategories == Set(RailViewCategory.allCases))
    #expect(railView.visibleTabID == nil)
    #expect(rootView.isContentHeaderViewHidden == false)

    try plugin.onShutdown(kernel: kernel)
}
