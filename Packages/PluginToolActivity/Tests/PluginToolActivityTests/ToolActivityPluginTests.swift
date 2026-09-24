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
}
