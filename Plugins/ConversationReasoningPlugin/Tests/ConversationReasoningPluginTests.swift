import LumiKernel
import Testing
@testable import ConversationReasoningPlugin

@Suite("ConversationReasoningPlugin")
@MainActor
struct ConversationReasoningPluginTests {
    @Test("contributes model selector sidebar item")
    func contributesSidebarItem() {
        let plugin = ConversationReasoningPlugin()
        let items = plugin.modelSelectorSidebarItems(kernel: LumiKernel())

        #expect(plugin.id == "com.coffic.lumi.plugin.conversation-reasoning")
        #expect(plugin.policy == .alwaysOn)
        #expect(items.map(\.id) == ["com.coffic.lumi.plugin.conversation-reasoning.model-selector"])
    }
}
