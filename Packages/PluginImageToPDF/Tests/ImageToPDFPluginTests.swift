import KernelCore
import ProviderActivityBar
import ProviderChatSection
import Testing
@testable import ImageToPDFPlugin

@MainActor
@Test func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)

    let plugin = ImageToPDFSuperPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(activityBar.activeItemID == "\(plugin.id).entry")
    #expect(!chat.isVisible)

    activityBar.activateItem(id: nil)

    #expect(chat.isVisible)
}
