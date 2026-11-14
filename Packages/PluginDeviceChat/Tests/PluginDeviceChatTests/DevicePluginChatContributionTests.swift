import Foundation
import KernelCore
import ProviderMessage
import ProviderMessageRendering
import ProviderToolManager
import Testing
import PluginDevice
@testable import PluginDeviceChat

/// 插件把工具与渲染器注册进内核、以及在禁用时撤回它们的行为。
@Suite("DevicePlugin 对话贡献点")
@MainActor
struct DevicePluginChatContributionTests {

    @Test("onBoot 注册 device_status 工具与卡片渲染器")
    func onBootRegistersToolAndRenderer() throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let rendering = DefaultMessageRenderingProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any MessageRenderingProviding).self, rendering)

        let plugin = DevicePlugin(chat: DeviceStatusChatContribution())
        try plugin.onBoot(kernel: kernel)

        #expect(toolManager.tool(named: DeviceStatusTool.toolName) != nil)
        #expect(rendering.allRenderers.contains { $0.id == DeviceStatusTimeline.rendererID })
    }

    /// 幂等：重复 boot 不应产生第二个渲染器或第二个工具。
    @Test("重复 onBoot 不会重复注册")
    func repeatedBootDoesNotDuplicateRegistrations() throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let rendering = DefaultMessageRenderingProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any MessageRenderingProviding).self, rendering)

        let plugin = DevicePlugin(chat: DeviceStatusChatContribution())
        try plugin.onBoot(kernel: kernel)
        try plugin.onBoot(kernel: kernel)

        let rendererCount = rendering.allRenderers.filter { $0.id == DeviceStatusTimeline.rendererID }.count
        #expect(rendererCount == 1)
        #expect(toolManager.allTools().filter { $0.name == DeviceStatusTool.toolName }.count == 1)
    }

    /// 内核在运行时禁用插件时只撤回 `trackContribution` 登记的贡献，
    /// 不会替插件清理 Provider 侧的写入。因此工具与渲染器必须由插件自己撤回，
    /// 否则设置里显示「已禁用」后 LLM 仍能调用该工具。
    @Test("onDisable 撤回工具与渲染器")
    func onDisableUnregistersToolAndRenderer() async throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let rendering = DefaultMessageRenderingProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any MessageRenderingProviding).self, rendering)

        let plugin = DevicePlugin(chat: DeviceStatusChatContribution())
        try plugin.onBoot(kernel: kernel)
        try await plugin.onDisable(kernel: kernel)

        #expect(toolManager.tool(named: DeviceStatusTool.toolName) == nil)
        #expect(!rendering.allRenderers.contains { $0.id == DeviceStatusTimeline.rendererID })
    }

    @Test("onShutdown 撤回工具与渲染器")
    func onShutdownUnregistersToolAndRenderer() throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let rendering = DefaultMessageRenderingProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any MessageRenderingProviding).self, rendering)

        let plugin = DevicePlugin(chat: DeviceStatusChatContribution())
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(toolManager.tool(named: DeviceStatusTool.toolName) == nil)
        #expect(!rendering.allRenderers.contains { $0.id == DeviceStatusTimeline.rendererID })
    }

    @Test("禁用后重新启用会恢复工具与渲染器")
    func onEnableRestoresToolAndRenderer() async throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let rendering = DefaultMessageRenderingProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any MessageRenderingProviding).self, rendering)

        let plugin = DevicePlugin(chat: DeviceStatusChatContribution())
        try plugin.onBoot(kernel: kernel)
        try await plugin.onDisable(kernel: kernel)
        try await plugin.onEnable(kernel: kernel)

        #expect(toolManager.tool(named: DeviceStatusTool.toolName) != nil)
        #expect(rendering.allRenderers.contains { $0.id == DeviceStatusTimeline.rendererID })
    }

    /// 缺少 ToolManagerProviding 时不应崩溃——精简宿主仍可只显示主内容。
    @Test("缺少工具与渲染器 Provider 时优雅降级")
    func onBootDegradesWithoutProviders() throws {
        let kernel = KernelCoreContainer()
        let plugin = DevicePlugin(chat: DeviceStatusChatContribution())

        try plugin.onBoot(kernel: kernel)
    }
}
