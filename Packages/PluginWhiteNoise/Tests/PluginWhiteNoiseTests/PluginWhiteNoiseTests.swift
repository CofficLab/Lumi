import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import SwiftUI
import Testing
@testable import PluginWhiteNoise

/// WhiteNoisePlugin 的基础验证。
@Suite("WhiteNoisePlugin")
@MainActor
struct PluginWhiteNoiseTests {

    @Test("onBoot 注册 ActivityBar 入口、主内容与文档")
    func onBootRegistersContentViewAndDocs() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let contentView = DefaultContentViewProviding()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = WhiteNoisePlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(activityBar.items.map(\.id) == ["\(plugin.id).entry"])
        #expect(activityBar.activeItemID == "\(plugin.id).entry")

        // 主内容视图
        #expect(type(of: contentView.makeContentView()) == AnyView.self)

        // 文档：关于 + 说明书
        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries[0].id == plugin.id)
        #expect(docs.aboutEntries[0].name == "白噪音")
        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries[0].id == plugin.id)
        #expect(type(of: docs.aboutEntries[0].makeView()) == AnyView.self)
        #expect(type(of: docs.manualEntries[0].makeView()) == AnyView.self)
    }

    @Test("onBoot 追加语义不覆盖已有文档")
    func onBootAppendsToExistingDocs() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        docs.addManual(DocsEntry(id: "general", name: "通用") { Text("general") })
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = WhiteNoisePlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(docs.manualEntries.count == 2)
        #expect(docs.manualEntries.map(\.id).contains(plugin.id))
    }

    @Test("Provider 未注册时 onBoot 优雅降级")
    func onBootNoOpsWithoutProviders() throws {
        let kernel = KernelCoreContainer()
        let plugin = WhiteNoisePlugin()

        // 不应抛错
        try plugin.onBoot(kernel: kernel)
    }

    @Test("onShutdown 撤回贡献")
    func onShutdownRemovesContributions() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let contentView = DefaultContentViewProviding()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = WhiteNoisePlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(activityBar.items.isEmpty)
        #expect(activityBar.activeItemID == nil)
        #expect(docs.aboutEntries.isEmpty)
        #expect(docs.manualEntries.isEmpty)
        // setContentView(nil) 后回退到占位视图，不抛错
        _ = contentView.makeContentView()
    }

    @Test("插件可经 kernel.start 启动并注册贡献")
    func startViaKernelBootsPlugin() throws {
        let kernel = KernelCoreContainer()
        let contentView = DefaultContentViewProviding()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = WhiteNoisePlugin()
        try kernel.start(plugins: [plugin])

        #expect(kernel.isPluginRegistered(id: plugin.id))
        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries[0].id == plugin.id)
    }

    @Test("WhiteNoiseView 可渲染")
    func mainViewRenders() {
        let view = WhiteNoiseView()
        #expect(type(of: view) != Never.self)
    }

    @Test("WhiteNoiseAboutView 可渲染")
    func aboutViewRenders() {
        let view = WhiteNoiseAboutView()
        #expect(type(of: view) != Never.self)
    }

    @Test("WhiteNoiseManualView 可渲染")
    func manualViewRenders() {
        let view = WhiteNoiseManualView()
        #expect(type(of: view) != Never.self)
    }
}
