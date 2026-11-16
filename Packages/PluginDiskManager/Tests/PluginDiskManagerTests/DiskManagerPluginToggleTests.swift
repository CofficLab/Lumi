import Foundation
import KernelCore
import ProviderStorage
import ProviderToolManager
import Testing
@testable import PluginDiskManager

/// 回归 #453：运行时禁用 Disk Manager 后，10 个 Agent 工具仍可执行。
///
/// 内核在运行时禁用插件时只撤回它**显式登记**的贡献，不会替插件清理
/// Provider 侧的写入。工具是直接 `toolManager.add` 进去的，不属于内核贡献，
/// 因此插件必须自己在 `onDisable` 里撤回，否则插件在设置里显示「已禁用」后，
/// LLM 仍能调用 `disk-manager.clean-caches`、`disk-manager.clean-projects`
/// 与 `disk-manager.delete-files` 这类有破坏性副作用的工具。
@MainActor
@Suite("Disk Manager 插件的运行时启停")
struct DiskManagerPluginToggleTests {

    @Test("运行时禁用后必须撤回全部 Agent 工具，含清理与删除")
    func disablingPluginWithdrawsAgentTools() async throws {
        let kernel = try await makeKernel()
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))

        // 前置：启用状态下工具都在。
        for tool in DiskManagerPlugin.agentTools {
            #expect(toolManager.tool(named: tool.name) != nil)
        }

        try await kernel.disablePlugin(id: Self.pluginID)

        for tool in DiskManagerPlugin.agentTools {
            #expect(toolManager.tool(named: tool.name) == nil, "\(tool.name) 未被撤回")
        }
    }

    @Test("运行时重新启用插件后恢复全部 Agent 工具")
    func enablingPluginRestoresAgentTools() async throws {
        let kernel = try await makeKernel()
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))

        try await kernel.disablePlugin(id: Self.pluginID)
        try await kernel.enablePlugin(id: Self.pluginID)

        for tool in DiskManagerPlugin.agentTools {
            #expect(toolManager.tool(named: tool.name) != nil, "\(tool.name) 未被恢复")
        }
    }

    @Test("禁用后清理与删除工具不得再进入执行路径")
    func disabledToolsAreNotExecutable() async throws {
        let kernel = try await makeKernel()
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))

        try await kernel.disablePlugin(id: Self.pluginID)

        // 禁用之后，工具管理器既解析不到也执行不了这些工具。
        #expect(toolManager.tool(named: "disk-manager.delete-files") == nil)
        #expect(toolManager.tool(named: "disk-manager.clean-caches") == nil)
        #expect(toolManager.allTools().allSatisfy { !$0.name.hasPrefix("disk-manager.") })
    }

    // MARK: - Helpers

    private static let pluginID = "com.coffic.lumi.plugin.disk-manager"

    /// 造一个已启动、且 Disk Manager 插件处于启用状态的内核。
    ///
    /// 必须走 `start(plugins:)`：运行时的禁用与启用要求内核处于 running 状态。
    /// 插件的策略是 `.disabledByDefault`，因此要先在状态存储里把它标成启用，
    /// 内核才会真正执行它的 `onBoot`。
    private func makeKernel() async throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ToolManagerProviding).self, DefaultToolManagerProviding())

        let stateDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskManagerToggle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        let stateStore = PluginEnabledStateStore(pluginDirectory: stateDirectory)
        stateStore.setEnabled(true, pluginID: Self.pluginID)
        kernel.stateStore = stateStore

        try kernel.start(plugins: [DiskManagerPlugin()])

        return kernel
    }
}