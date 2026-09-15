import Testing
import KernelCore
import OpenInKit
import ProviderDocsView
import ProviderToolManager
import ProviderToolbar
@testable import PluginOpenInAntigravity

@MainActor
@Test("启动时注册对应工具、文档和左侧工具栏贡献，关闭时一并撤回")
func pluginRegistersAndRemovesToolDocumentationAndToolbarItem() throws {
    let kernel = KernelCoreContainer()
    let docs = DefaultDocsViewProviding()
    let tools = DefaultToolManagerProviding()
    let toolbar = DefaultToolbarProviding()
    try kernel.registerProvider((any DocsViewProviding).self, docs)
    try kernel.registerProvider((any ToolManagerProviding).self, tools)
    try kernel.registerProvider((any ToolbarProviding).self, toolbar)
    let plugin = OpenInAntigravityPlugin()

    #expect(plugin.id == "com.coffic.lumi.plugin.open-in-antigravity")
    #expect(plugin.metadata.policy == .disabledByDefault)
    try plugin.onRegister(kernel: kernel)
    #expect(docs.aboutEntries.map(\.id) == [plugin.id])
    #expect(docs.manualEntries.map(\.id) == [plugin.id])
    _ = docs.aboutEntries[0].makeView()
    _ = docs.manualEntries[0].makeView()

    try plugin.onBoot(kernel: kernel)
    #expect(tools.allTools().map(\.name) == [OpenInTool.antigravity.toolName])
    #expect(tools.toolsGroupedByPlugin().first?.pluginID == plugin.id)
    #expect(toolbar.toolbarItems.map(\.id) == ["\(plugin.id).toolbar"])
    #expect(toolbar.toolbarItems.first?.placement == .leading)

    try plugin.onShutdown(kernel: kernel)

    #expect(tools.allTools().isEmpty)
    #expect(toolbar.toolbarItems.isEmpty)
    #expect(docs.aboutEntries.isEmpty)
    #expect(docs.manualEntries.isEmpty)
}

@MainActor
@Test("缺少可选 Provider 时生命周期回调安全降级")
func pluginToleratesMissingProviders() throws {
    let plugin = OpenInAntigravityPlugin()
    let kernel = KernelCoreContainer()

    try plugin.onRegister(kernel: kernel)
    try plugin.onBoot(kernel: kernel)
    try plugin.onShutdown(kernel: kernel)

    #expect(plugin.id == plugin.metadata.id)
}
