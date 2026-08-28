import KernelCore
import PluginChatPanel
import ProviderActivityBar
import ProviderChatSection
import ProviderRootView
import ProviderRailView
import Testing

@Suite("ChatPanelPlugin")
@MainActor
struct ChatPanelPluginTests {

    @Test("激活 Chat 时隐藏 RootView 内容，切换入口时恢复")
    func chatActivationTogglesRootContentVisibility() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProvider()
        let railView = DefaultRailViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(rootView.isContentViewHidden)
        #expect(chat.isVisible)
        #expect(railView.visibleCategories == [.chat])

        let otherEntryID = "test.other.entry"
        activityBar.addItems([ActivityBarItem(
            id: otherEntryID,
            title: "Other",
            systemImage: "square"
        )])
        activityBar.activateItem(id: otherEntryID)

        #expect(!rootView.isContentViewHidden)
        #expect(!chat.isVisible)
        #expect(railView.visibleCategories == Set(RailViewCategory.allCases))

        activityBar.activateItem(id: plugin.id + ".entry")
        #expect(rootView.isContentViewHidden)
        #expect(railView.visibleCategories == [.chat])
        try plugin.onShutdown(kernel: kernel)

        #expect(!rootView.isContentViewHidden)
        #expect(!chat.isVisible)
        #expect(railView.visibleCategories == Set(RailViewCategory.allCases))
    }
}
