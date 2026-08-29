import Testing
import KernelCore
import ProviderActivityBar
import ProviderChatSection
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
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)

    let plugin = TerminalSuperPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(activityBar.activeItemID == "\(plugin.id).entry")
    #expect(!chat.isVisible)

    activityBar.activateItem(id: nil)

    #expect(chat.isVisible)
}
