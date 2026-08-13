import KernelLumi
import Testing
@testable import ConversationReasoningPlugin

@Suite("ConversationReasoningPlugin")
@MainActor
struct ConversationReasoningPluginTests {
    @Test("contributes chat action bar item")
    func contributesActionBarItem() {
        let plugin = ConversationReasoningPlugin()
        let items = plugin.chatSectionActionBarItems(kernel: KernelLumi())

        #expect(plugin.id == "com.coffic.lumi.plugin.conversation-reasoning")
        #expect(plugin.policy == .alwaysOn)
        #expect(plugin.order == 81)
        #expect(items.map(\.id) == ["com.coffic.lumi.plugin.conversation-reasoning.action-bar-button"])
        if let placement = items.first?.placement {
            guard case .leading = placement else {
                Issue.record("Expected leading placement")
                return
            }
        } else {
            Issue.record("Expected one action bar item")
        }
    }
}
