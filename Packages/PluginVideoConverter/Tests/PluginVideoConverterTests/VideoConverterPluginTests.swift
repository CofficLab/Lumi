import KernelCore
import ProviderContentView
import ProviderDocsView
import SwiftUI
import Testing
@testable import PluginVideoConverter

/// VideoConverterPlugin 的基础验证。
@Suite("VideoConverterPlugin")
@MainActor
struct VideoConverterPluginTests {

    @Test("onBoot 注册主内容与文档")
    func onBootRegistersContentViewAndDocs() throws {
        let kernel = KernelCoreContainer()
        let contentView = DefaultContentViewProviding()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = VideoConverterPlugin()
        try plugin.onBoot(kernel: kernel)

        // 主内容视图
        #expect(type(of: contentView.makeContentView()) == AnyView.self)

        // 文档：关于 + 说明书
        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries[0].id == plugin.id)
        #expect(docs.aboutEntries[0].name == "视频转换")
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

        let plugin = VideoConverterPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(docs.manualEntries.count == 2)
        #expect(docs.manualEntries.map(\.id).contains(plugin.id))
    }

    @Test("Provider 未注册时 onBoot 优雅降级")
    func onBootNoOpsWithoutProviders() throws {
        let kernel = KernelCoreContainer()
        let plugin = VideoConverterPlugin()

        // 不应抛错
        try plugin.onBoot(kernel: kernel)
    }

    @Test("插件可经 kernel.start 启动并注册贡献")
    func startViaKernelBootsPlugin() throws {
        let kernel = KernelCoreContainer()
        let contentView = DefaultContentViewProviding()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = VideoConverterPlugin()
        try kernel.start(plugins: [plugin])

        #expect(kernel.isPluginRegistered(id: plugin.id))
        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries[0].id == plugin.id)
    }

    @Test("onShutdown 撤回主内容与文档贡献")
    func onShutdownWithdrawsContributions() throws {
        let kernel = KernelCoreContainer()
        let contentView = DefaultContentViewProviding()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = VideoConverterPlugin()
        try kernel.start(plugins: [plugin])
        #expect(docs.aboutEntries.count == 1)

        try kernel.stop()

        #expect(docs.aboutEntries.isEmpty)
        #expect(docs.manualEntries.isEmpty)
    }

    @Test("VideoConverterMainView 可渲染")
    func mainViewRenders() {
        let view = VideoConverterMainView()
        #expect(type(of: view) != Never.self)
    }

    @Test("VideoConverterAboutView 可渲染")
    func aboutViewRenders() {
        let view = VideoConverterAboutView()
        #expect(type(of: view) != Never.self)
    }

    @Test("VideoConverterManualView 可渲染")
    func manualViewRenders() {
        let view = VideoConverterManualView()
        #expect(type(of: view) != Never.self)
    }
}
