import KernelCore
import ProviderToolManager
import Testing
@testable import PluginDocxRead

@Test @MainActor func pluginRegistersAndRemovesItsAgentTools() throws {
    let kernel = KernelCoreContainer()
    let tools = DefaultToolManagerProviding()
    try kernel.registerProvider((any ToolManagerProviding).self, tools)
    let plugin = DocxReadPlugin()

    try plugin.onBoot(kernel: kernel)

    #expect(plugin.id == "com.coffic.lumi.plugin.docx-read")
    #expect(plugin.order == 90)
    #expect(!plugin.name.isEmpty)
    #expect(tools.tool(named: "read_docx") != nil)
    #expect(tools.toolsGroupedByPlugin().map(\.pluginID) == [plugin.id])

    try plugin.onShutdown(kernel: kernel)
    #expect(tools.tool(named: "read_docx") == nil)
    #expect(tools.toolsGroupedByPlugin().isEmpty)
}

@Test @MainActor func pluginLifecycleToleratesMissingToolManager() throws {
    let plugin = DocxReadPlugin()
    let kernel = KernelCoreContainer()

    try plugin.onBoot(kernel: kernel)
    try plugin.onShutdown(kernel: kernel)
}
