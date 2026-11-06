import Foundation
import KernelCore
import ProviderMessage
import ProviderMessageRendering
import ProviderStorage
import ProviderToolManager
import Testing
@testable import FactoryLumi

/// 「Finder」插件的运行时启停验证。
///
/// ## 为什么要有这组用例
///
/// 插件在 `onBoot` 里把工具与渲染器写进共享 Provider。内核在运行时禁用插件时
/// 只撤回它**显式登记**的贡献（`trackContribution`），不会替插件去清理
/// Provider 侧的写入——因此插件必须自己在 `onDisable` 里撤回。
///
/// 少了这一步的症状很隐蔽：插件在设置里显示「已禁用」，但 LLM 仍能调用
/// `show_folder_card`，聊天区也仍会渲染卡片。这类问题只靠读代码看不出来，
/// 必须真的启停一次才能发现。
@MainActor
@Suite("FactoryLumi · PluginFinder 启停")
struct FinderPluginToggleTests {

    private static let pluginID = "com.coffic.lumi.plugin.finder"
    private static let rendererID = "com.coffic.lumi.plugin.finder.card"
    private static let toolName = "show_folder_card"

    @Test("运行时禁用插件后撤回工具与渲染器")
    func disablingPluginWithdrawsToolAndRenderer() async throws {
        let kernel = try makeKernelWithFinderEnabled()

        // 前置：启用状态下两者都在。
        #expect(kernel.resolveProvider((any ToolManagerProviding).self)?.tool(named: Self.toolName) != nil)
        #expect(
            kernel.resolveProvider((any MessageRenderingProviding).self)?
                .allRenderers.contains { $0.id == Self.rendererID } == true
        )

        try await kernel.disablePlugin(id: Self.pluginID)

        #expect(kernel.resolveProvider((any ToolManagerProviding).self)?.tool(named: Self.toolName) == nil)
        #expect(
            kernel.resolveProvider((any MessageRenderingProviding).self)?
                .allRenderers.contains { $0.id == Self.rendererID } == false
        )
    }

    @Test("运行时重新启用插件后恢复工具与渲染器")
    func enablingPluginRestoresToolAndRenderer() async throws {
        let kernel = try makeKernelWithFinderEnabled()

        try await kernel.disablePlugin(id: Self.pluginID)
        try await kernel.enablePlugin(id: Self.pluginID)

        #expect(kernel.resolveProvider((any ToolManagerProviding).self)?.tool(named: Self.toolName) != nil)
        #expect(
            kernel.resolveProvider((any MessageRenderingProviding).self)?
                .allRenderers.contains { $0.id == Self.rendererID } == true
        )
    }

    // MARK: - Helpers

    /// 造一个启用了Finder 插件的内核。
    private func makeKernelWithFinderEnabled() throws -> KernelCoreContainer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinderToggleTests-\(UUID().uuidString)", isDirectory: true)
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
