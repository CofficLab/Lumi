import Foundation
import Testing
import KernelCore
import ProviderDocsView
import ProviderGit
import ProviderProject
import ProviderToast
import ProviderToolManager
import ProviderToolbar
@testable import PluginOpenInRemote

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
    let plugin = OpenInRemotePlugin()

    #expect(plugin.id == "com.coffic.lumi.plugin.open-in-remote")
    #expect(plugin.metadata.policy == .disabledByDefault)
    try plugin.onRegister(kernel: kernel)
    #expect(docs.aboutEntries.map(\.id) == [plugin.id])
    #expect(docs.manualEntries.map(\.id) == [plugin.id])
    _ = docs.aboutEntries[0].makeView()
    _ = docs.manualEntries[0].makeView()

    try plugin.onBoot(kernel: kernel)
    #expect(tools.allTools().map(\.name) == [OpenInRemoteConstants.toolName])
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
    let plugin = OpenInRemotePlugin()
    let kernel = KernelCoreContainer()

    try plugin.onRegister(kernel: kernel)
    try plugin.onBoot(kernel: kernel)
    try plugin.onShutdown(kernel: kernel)

    #expect(plugin.id == plugin.metadata.id)
}

@MainActor
@Test("注册 Git 与项目能力后可解析远程仓库 web 链接")
func pluginResolvesRemoteWebURLWithProviders() async throws {
    let kernel = KernelCoreContainer()
    let git = InMemoryGitRepositoryReading()
    git.setRemoteURL("git@github.com:user/repo.git", forPath: "/repo")
    try kernel.registerProvider((any GitRepositoryReading).self, git)

    let plugin = OpenInRemotePlugin()
    try plugin.onBoot(kernel: kernel)

    let resolver = RemoteRepositoryResolver(
        gitCapability: OpenInRemoteGitCapabilityAdapter(provider: git)
    )
    let url = await resolver.webURL(forRepositoryAt: "/repo")

    #expect(url?.absoluteString == "https://github.com/user/repo")

    try plugin.onShutdown(kernel: kernel)
}
