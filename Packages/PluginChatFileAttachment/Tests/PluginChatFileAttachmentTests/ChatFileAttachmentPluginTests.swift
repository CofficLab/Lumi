import KernelCore
import ProviderChatSection
import Testing
@testable import PluginChatFileAttachment

@Test @MainActor func pluginRegistersTheFilePickerInTheLeadingActionBarAndRemovesIt() throws {
    let kernel = KernelCoreContainer()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    let plugin = ChatFileAttachmentPlugin()

    try plugin.onBoot(kernel: kernel)

    #expect(plugin.id == "com.coffic.lumi.plugin.chat-file-attachment")
    #expect(plugin.order == 81)
    #expect(!plugin.name.isEmpty)
    #expect(chat.barItems.map(\.id) == ["\(plugin.id).button"])
    #expect(chat.barItems.first?.order == 82)
    #expect(chat.barItems.first?.placement == .actionLeading)

    try plugin.onShutdown(kernel: kernel)
    #expect(chat.barItems.isEmpty)
}

@Test @MainActor func pluginLifecycleToleratesMissingChatProvider() throws {
    let plugin = ChatFileAttachmentPlugin()
    let kernel = KernelCoreContainer()

    try plugin.onBoot(kernel: kernel)
    try plugin.onShutdown(kernel: kernel)
}
