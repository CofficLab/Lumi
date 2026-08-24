import Testing
import KernelCore
import ProviderActivityBar
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
