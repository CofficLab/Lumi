import KernelCore
import ProviderActivityBar
import ProviderRailView
import ProviderRootView
import Testing
@testable import PluginBookletMaker

@MainActor
@Test func activatingPluginInvokesWorkspaceHooksAndDeactivatingRestoresLayout() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    let rail = DefaultRailViewProviding(visibleCategories: [.chat])
    let root = DefaultRootViewProviding()
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any RailViewProviding).self, rail)
    try kernel.registerProvider((any RootViewProviding).self, root)

    activityBar.addItems([ActivityBarItem(id: "chat.entry", title: "Chat", systemImage: "message")])

    // 宿主注入的聊天区显隐钩子：插件本身不感知聊天区实现。
    var didHideChat = false
    var didRestoreChat = false
    let plugin = BookletMakerPlugin(
        onWorkspaceActivate: { didHideChat = true },
        onWorkspaceDeactivate: { didRestoreChat = true }
    )
    try plugin.onBoot(kernel: kernel)

    #expect(activityBar.activeItemID == "chat.entry")

    activityBar.activateItem(id: "\(plugin.id).entry")

    #expect(didHideChat)
    #expect(!didRestoreChat)
    #expect(rail.visibleCategories == [.design])
    #expect(rail.visibleTabID == BookletMakerPlugin.railTabID)
    #expect(rail.activeTabID == BookletMakerPlugin.railTabID)
    #expect(root.isContentHeaderViewHidden)

    activityBar.activateItem(id: nil)

    #expect(didRestoreChat)
    #expect(rail.visibleCategories == Set(RailViewCategory.allCases))
    #expect(root.isContentHeaderViewHidden == false)
}

@MainActor
@Test func pluginWithoutWorkspaceHooksStillBootsAndTogglesLayout() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    let rail = DefaultRailViewProviding(visibleCategories: [.chat])
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any RailViewProviding).self, rail)
    activityBar.addItems([ActivityBarItem(id: "chat.entry", title: "Chat", systemImage: "message")])

    // GameFactory 等没有聊天区的宿主不传钩子，插件仍需正常启动。
    let plugin = BookletMakerPlugin()
    try plugin.onBoot(kernel: kernel)

    activityBar.activateItem(id: "\(plugin.id).entry")
    #expect(rail.visibleTabID == BookletMakerPlugin.railTabID)

    activityBar.activateItem(id: nil)
    #expect(rail.visibleCategories == Set(RailViewCategory.allCases))
}

@MainActor
@Test func pluginIdentityIsInjectedPerHost() {
    #expect(BookletMakerPlugin().id == BookletMakerPlugin.defaultPluginID)

    let custom = BookletMakerPlugin(id: "com.coffic.bookletmaker.plugin.booklet-maker")
    #expect(custom.id == "com.coffic.bookletmaker.plugin.booklet-maker")
    #expect(custom.metadata.id == custom.id)
}

@MainActor
@Test func policyCanBeConfiguredPerHost() {
    #expect(BookletMakerPlugin().metadata.policy == .disabledByDefault)
    #expect(BookletMakerPlugin(policy: .required).metadata.policy == .required)
    #expect(BookletMakerPlugin(policy: .alwaysOn).metadata.policy == .alwaysOn)
}
