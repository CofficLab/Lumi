import Foundation
import KernelCore
import ProviderMenuBar
import ProviderSettingView
import ProviderStorage
import ProviderToolManager
import Testing
@testable import PluginNetworkManager

@Suite("NetworkManager 禁用生命周期", HTTPExchangeStoreGateTrait())
@MainActor
struct NetworkManagerDisableLifecycleTests {
    @Test("运行时禁用撤回 7 个工具、停止采样并清空交换存储，重新启用恢复（**回归 #449**）")
    func disableWithdrawsToolsAndStopsMonitoring() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetworkManagerDisable-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let kernel = KernelCoreContainer()
        let menuBar = DefaultMenuBarProviding()
        let toolManager = DefaultToolManagerProviding()
        let settingView = DefaultSettingViewProviding()
        let storage = DefaultStorageProvider(dataRootDirectory: root)
        try kernel.registerProvider((any MenuBarProviding).self, menuBar)
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any SettingViewProviding).self, settingView)
        try kernel.registerProvider((any StorageProviding).self, storage)

        let plugin = NetworkManagerPlugin()
        let toolNames = NetworkManagerPlugin.agentTools.map(\.name)
        #expect(toolNames.count == 7)
        try kernel.start(plugins: [plugin])

        // Boot 后：7 个工具、采样、设置入口、交换存储与菜单栏都在。
        for name in toolNames { #expect(toolManager.tool(named: name) != nil) }
        #expect(NetworkService.shared.isMonitoringForTesting)
        #expect(NetworkService.shared.currentExchangeStore != nil)
        #expect(settingView.entries.contains { $0.id == "\(plugin.id).settings" })
        #expect(menuBar.contentItems.map(\.id) == ["\(plugin.id).speed"])

        // 运行时禁用：内核只撤回经 trackContribution 登记的菜单栏贡献，工具、
        // 采样、设置入口与交换存储必须由插件 onDisable 自行撤回与停止（#449）。
        try await kernel.disablePlugin(id: plugin.id)
        for name in toolNames { #expect(toolManager.tool(named: name) == nil) }
        #expect(!NetworkService.shared.isMonitoringForTesting)
        #expect(NetworkService.shared.currentExchangeStore == nil)
        #expect(!settingView.entries.contains { $0.id == "\(plugin.id).settings" })
        #expect(menuBar.contentItems.isEmpty)
        #expect(menuBar.popupItems.isEmpty)

        // 重新启用：恢复全部运行时资源与贡献。
        try await kernel.enablePlugin(id: plugin.id)
        for name in toolNames { #expect(toolManager.tool(named: name) != nil) }
        #expect(NetworkService.shared.isMonitoringForTesting)
        #expect(NetworkService.shared.currentExchangeStore != nil)
        #expect(settingView.entries.contains { $0.id == "\(plugin.id).settings" })
        #expect(menuBar.contentItems.map(\.id) == ["\(plugin.id).speed"])

        try kernel.stop()
        #expect(!NetworkService.shared.isMonitoringForTesting)
        for name in toolNames { #expect(toolManager.tool(named: name) == nil) }
        #expect(NetworkService.shared.currentExchangeStore == nil)
    }
}