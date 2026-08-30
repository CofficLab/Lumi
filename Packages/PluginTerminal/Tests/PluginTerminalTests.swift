import Testing
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderRailView
import ProviderRootView
import SwiftUI
@testable import TerminalPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@MainActor
@Test func v2PluginRegistersStableTerminalEntry() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)

    let plugin = TerminalSuperPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(plugin.id == "com.coffic.lumi.plugin.terminal")
    #expect(activityBar.items.map(\.id) == ["com.coffic.lumi.plugin.terminal.entry"])
}

@MainActor
@Test func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    let chat = DefaultChatSectionProviding()
    let railView = DefaultRailViewProviding()
    let rootView = DefaultRootViewProvider()

    railView.addTabs([
        RailTabItem(id: "test.rail", category: .general, title: "Test", systemImage: "circle") {
            Text("Test")
        },
    ])
    rootView.setRailView(railView.makeRailView())
    rootView.setRailViewVisible(railView.hasVisibleTabs)

    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any RailViewProviding).self, railView)
    try kernel.registerProvider((any RootViewProviding).self, rootView)

    let plugin = TerminalSuperPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(activityBar.activeItemID == "\(plugin.id).entry")
    #expect(!chat.isVisible)
    #expect(!rootView.isRailViewVisible)
    #expect(rootView.isContentHeaderViewHidden)

    activityBar.activateItem(id: nil)

    #expect(chat.isVisible)
    #expect(rootView.isRailViewVisible)
    #expect(rootView.isContentHeaderViewHidden == false)
}
