import Foundation
import KernelCore
import ProviderMessage
import ProviderMessageRendering
import ProviderStorage
import ProviderToolManager
import Testing
@testable import FactoryLumi

/// 「HTML 画布」插件在装配层的接线验证。
///
/// ## 为什么要有这组用例
///
/// 插件本体已经能证明「工具 → 消息 → 渲染器」这条链路成立，但那只在
/// 插件单独存在时成立。真正会出问题的是**装配层**：包依赖漏了、插件没进
/// `makePlugins()` 目录、或者 `disabledByDefault` 让它默认不启动——
/// 这些都不会让插件自己的测试失败，只会让功能在真实应用里静默消失。
///
/// 因此这里从 `KernelFactory.makeKernel()` 这一真实入口验证：
/// 插件进了目录、能被启用、启用后工具与渲染器都真的注册上了。
@MainActor
@Suite("FactoryLumi · PluginHTMLCanvas")
struct HTMLCanvasPluginAssemblyTests {

    /// 插件 ID，与 `HTMLCanvasPlugin.id` 一致。
    private static let pluginID = "com.coffic.lumi.plugin.html-canvas"

    /// 卡片渲染器 ID，与 `HTMLCanvasTimeline.rendererID` 一致。
    private static let rendererID = "com.coffic.lumi.plugin.html-canvas.card"

    @Test("默认插件目录包含 HTML 画布插件")
    func defaultFactoryIncludesHTMLCanvasPlugin() {
        let plugins = Dictionary(
            uniqueKeysWithValues: DefaultPluginFactory().makePlugins().map { ($0.id, $0) }
        )

        let plugin = plugins[Self.pluginID]
        #expect(plugin != nil)
        #expect(plugin?.metadata.policy == .disabledByDefault)
    }

    @Test("启用插件后注册 show_html 工具与卡片渲染器")
    func enabledPluginRegistersToolAndRenderer() throws {
        let kernel = try makeKernelWithHTMLCanvasEnabled()

        // 工具已注册，LLM 因此能调用它。
        let toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        #expect(toolManager?.tool(named: "show_html") != nil)

        // 卡片渲染器已注册，且能命中画布消息。
        let rendering = kernel.resolveProvider((any MessageRenderingProviding).self)
        #expect(rendering?.allRenderers.contains { $0.id == Self.rendererID } == true)

        let canvas = Message(
            conversationID: UUID(),
            role: .system,
            content: "画布",
            renderKind: MessageTimelineEvent.htmlCanvasRenderKind
        )
        #expect(rendering?.renderer(for: canvas)?.id == Self.rendererID)
    }

    @Test("插件停用后不注册工具与渲染器")
    func disabledPluginRegistersNothing() throws {
        // 该插件默认 disabledByDefault，未显式启用时不应注册任何贡献。
        let kernel = try KernelFactory.makeKernel()

        let toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        #expect(toolManager?.tool(named: "show_html") == nil)

        let rendering = kernel.resolveProvider((any MessageRenderingProviding).self)
        #expect(rendering?.allRenderers.contains { $0.id == Self.rendererID } == false)
    }

    // MARK: - Helpers

    /// 造一个启用了 HTML 画布插件的内核。
    ///
    /// 插件是 `disabledByDefault`，必须先在状态存储里显式开启才会被启动。
    private func makeKernelWithHTMLCanvasEnabled() throws -> KernelCoreContainer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLCanvasAssemblyTests-\(UUID().uuidString)", isDirectory: true)
        let storage = DefaultStorageProvider(dataRootDirectory: root)
        let stateStore = PluginEnabledStateStore(
            pluginDirectory: storage.pluginDataDirectory(for: "com.coffic.lumi.plugin.plugin-manager")
        )
        stateStore.setEnabled(true, pluginID: Self.pluginID)

        let providerFactory = DefaultProviderFactory(dataRootDirectory: root)
        return try KernelFactory.makeKernel(
            providerFactory: providerFactory,
            pluginFactory: DefaultPluginFactory()
        )
    }
}
