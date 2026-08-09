import Testing
@testable import TextActionsPlugin

@MainActor
@Test
func pluginMetadata() {
    let plugin = TextActionsPlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.text-actions")
    #expect(plugin.viewContainers(kernel: .init()).count == 1)
}
