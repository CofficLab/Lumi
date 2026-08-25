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
    #expect(manager is ToolManager)
    #expect(!manager.allTools().isEmpty)
    #expect(manager.tool(named: "read_file") != nil)
}

@MainActor
@Test func toolManagerEventManagerDispatchesAndCancelsObservers() async {
    let manager = ToolManager()
    var eventCount = 0
    let handle = manager.addToolManagerObserver { _ in
        eventCount += 1
    }

    _ = await manager.executeBatch(
        [],
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: nil
    )
    #expect(eventCount == 1)

    handle.cancel()

    _ = await manager.executeBatch(
        [],
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: nil
    )
    #expect(eventCount == 1)
}
