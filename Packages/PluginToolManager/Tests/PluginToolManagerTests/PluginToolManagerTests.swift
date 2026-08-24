import KernelCore
import ProviderToolManager
import Testing
@testable import PluginToolManager

@MainActor
@Test func toolManagerPluginReplacesFallbackAndRegistersBuiltinTools() throws {
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any ToolManagerProviding).self, DefaultToolManagerProviding())

    let plugin = PluginToolManager()
    try plugin.onBoot(kernel: kernel)

    let manager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
    #expect(manager is ToolManagerService)
    #expect(!manager.allTools().isEmpty)
    #expect(manager.tool(named: "read_file") != nil)
}
