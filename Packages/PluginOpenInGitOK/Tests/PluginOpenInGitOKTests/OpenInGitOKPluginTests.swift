import Testing
import KernelCore
import OpenInKit
import ProviderDocsView
import ProviderToolManager
@testable import PluginOpenInGitOK

@MainActor
@Test("启动时注册对应工具与文档，关闭时一并撤回")
func pluginRegistersAndRemovesToolAndDocumentation() throws {
    let kernel = KernelCoreContainer()
    let docs = DefaultDocsViewProviding()
    let tools = DefaultToolManagerProviding()
    try kernel.registerProvider((any DocsViewProviding).self, docs)
    try kernel.registerProvider((any ToolManagerProviding).self, tools)
    let plugin = OpenInGitOKPlugin()

    #expect(plugin.id == "com.coffic.lumi.plugin.open-in-gitok")
    #expect(plugin.metadata.policy == .enabledByDefault)
    try plugin.onRegister(kernel: kernel)
    #expect(docs.aboutEntries.map(\.id) == [plugin.id])
    #expect(docs.manualEntries.map(\.id) == [plugin.id])
    _ = docs.aboutEntries[0].makeView()
    _ = docs.manualEntries[0].makeView()

    try plugin.onBoot(kernel: kernel)
    #expect(tools.allTools().map(\.name) == [OpenInTool.gitOK.toolName])
    #expect(tools.toolsGroupedByPlugin().first?.pluginID == plugin.id)

    try plugin.onShutdown(kernel: kernel)

    #expect(tools.allTools().isEmpty)
    #expect(docs.aboutEntries.isEmpty)
    #expect(docs.manualEntries.isEmpty)
}

@MainActor
@Test("缺少可选 Provider 时生命周期回调安全降级")
func pluginToleratesMissingProviders() throws {
    let plugin = OpenInGitOKPlugin()
    let kernel = KernelCoreContainer()

    try plugin.onRegister(kernel: kernel)
    try plugin.onBoot(kernel: kernel)
    try plugin.onShutdown(kernel: kernel)

    #expect(plugin.id == plugin.metadata.id)
}
