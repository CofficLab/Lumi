import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderRailView
import ProviderRootView
import Testing
@testable import BookletMakerPlugin

@MainActor
@Test func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    let chat = DefaultChatSectionProviding()
    let rail = DefaultRailViewProviding(visibleCategories: [.chat])
    let root = DefaultRootViewProvider()
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any RailViewProviding).self, rail)
    try kernel.registerProvider((any RootViewProviding).self, root)

    activityBar.addItems([ActivityBarItem(id: "chat.entry", title: "Chat", systemImage: "message")])

    let plugin = BookletMakerPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(activityBar.activeItemID == "chat.entry")

    activityBar.activateItem(id: "\(plugin.id).entry")

    #expect(!chat.isVisible)
    #expect(rail.visibleCategories == [.design])
    #expect(rail.visibleTabID == BookletMakerPlugin.railTabID)
    #expect(rail.activeTabID == BookletMakerPlugin.railTabID)
    #expect(root.isContentHeaderViewHidden)

    activityBar.activateItem(id: nil)

    #expect(chat.isVisible)
    #expect(rail.visibleCategories == Set(RailViewCategory.allCases))
    #expect(root.isContentHeaderViewHidden == false)
}
