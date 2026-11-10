import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderToolManager
import Testing
@testable import PluginToolActivity

@Suite("Tool Activity Plugin")
@MainActor
struct ToolActivityPluginTests {
    @Test("Registers as a chat plugin")
    func metadata() {
        let plugin = ToolActivityPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.tool-activity")
        #expect(plugin.order == 87)
        #expect(plugin.metadata.category == .chat)
    }

    @Test("Runtime disable removes the toolbar item and re-enable restores it")
    func disableRemovesToolbarItem() async throws {
        let kernel = KernelCoreContainer()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ConversationManaging).self, DefaultConversationManager())
        try kernel.registerProvider((any ToolManagerProviding).self, DefaultToolManagerProviding())

        let plugin = ToolActivityPlugin()
        let barItemID = "\(plugin.id).toolbar"

        try plugin.onBoot(kernel: kernel)
        #expect(chat.barItems.contains { $0.id == barItemID })

        try await plugin.onDisable(kernel: kernel)
        #expect(!chat.barItems.contains { $0.id == barItemID })

        try plugin.onBoot(kernel: kernel)
        #expect(chat.barItems.contains { $0.id == barItemID })
    }
}
