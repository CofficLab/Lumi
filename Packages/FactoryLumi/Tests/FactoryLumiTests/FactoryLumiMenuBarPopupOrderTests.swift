import Foundation
import KernelCore
import ProviderMenuBar
import ProviderStorage
import Testing
@testable import FactoryLumi

/// 菜单栏弹出菜单的呈现顺序（集成层）。
///
/// 远程包 `LumiPluginCaffeinate` 把弹窗的**呈现权重**与插件**启动顺序**解耦，
/// 默认把防休眠排在弹出菜单最前。这里用真实内核启动验证最终结果。
@Suite("FactoryLumi 菜单栏弹出顺序")
@MainActor
struct FactoryLumiMenuBarPopupOrderTests {

    /// 用隔离的数据目录启动真实内核，避免读写开发者本机的真实配置。
    private func makeKernel() throws -> KernelCoreContainer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FactoryLumiMenuBarOrderTests-\(UUID().uuidString)", isDirectory: true)
        let providerFactory = DefaultProviderFactory(dataRootDirectory: root)
        return try KernelFactory.makeKernel(
            providerFactory: providerFactory,
            pluginFactory: DefaultPluginFactory()
        )
    }

    @Test("防休眠弹窗排在弹出菜单最前")
    func caffeinatePopupComesFirst() throws {
        let kernel = try makeKernel()
        defer { try? kernel.stop() }

        let menuBar = try #require(kernel.resolveProvider((any MenuBarProviding).self))
        let popups = menuBar.popupItems

        #expect(!popups.isEmpty, "expected at least one popup contribution")

        // 防休眠插件默认启用，其弹窗必须在第一位。
        let caffeinatePopup = try #require(
            popups.first { $0.ownerPluginID == "com.coffic.lumi.plugin.caffeinate" },
            "anti-sleep popup should be contributed"
        )
        #expect(popups.first?.id == caffeinatePopup.id)

        // 呈现权重与启动顺序解耦：防休眠的启动顺序是 7，呈现权重是 0。
        #expect(caffeinatePopup.order == 0)
    }
}
