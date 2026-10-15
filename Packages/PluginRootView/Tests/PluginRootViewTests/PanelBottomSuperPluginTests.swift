import KernelCore
import ProviderPanelBottom
import ProviderRootView
import SwiftUI
import Testing
@testable import PluginRootView

/// PanelBottomPlugin 宿主生命周期测试。
///
/// 覆盖点：
/// - `onBoot` 注册 `PanelBottomProviding`，入口变化时安装/撤回 footer 容器；
/// - 内核重启（onShutdown → onBoot）复用 provider 实例并恢复容器。
@Suite("PanelBottomPlugin")
@MainActor
struct PanelBottomSuperPluginTests {

    private func makePlugin() throws -> (PanelBottomPlugin, KernelCoreContainer, LumiRootViewProvider) {
        let kernel = KernelCoreContainer()
        let rootView = LumiRootViewProvider()
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        let plugin = PanelBottomPlugin()
        try plugin.onBoot(kernel: kernel)
        return (plugin, kernel, rootView)
    }

    @Test("注册 PanelBottomProviding 并按入口安装/撤回 footer 容器")
    func installsAndUninstallsFooterContainer() throws {
        let (plugin, kernel, rootView) = try makePlugin()
        let provider = try #require(kernel.resolveProvider((any PanelBottomProviding).self))

        #expect(provider.hasVisibleItems == false)
        #expect(rootView.view(for: .contentFooter) == nil)

        provider.addItems([
            PanelBottomItem(id: "test.preview", title: "Preview", ownerPluginID: "test") {
                AnyView(Text("preview"))
            }
        ])
        #expect(provider.activeItemID == "test.preview")
        #expect(rootView.view(for: .contentFooter) != nil)

        provider.removeItems(ownerPluginID: "test")
        #expect(provider.hasVisibleItems == false)
        #expect(rootView.view(for: .contentFooter) == nil)

        try plugin.onShutdown(kernel: kernel)
        // provider 通过 registerHostProvider 注册（宿主持有），保留注册状态。
        #expect(kernel.resolveProvider((any PanelBottomProviding).self) != nil)
    }

    @Test("内核重启复用 provider 实例并恢复容器")
    func reusesProviderAcrossKernelRestart() throws {
        let (plugin, kernel, rootView) = try makePlugin()
        let provider = try #require(kernel.resolveProvider((any PanelBottomProviding).self))
        provider.addItems([
            PanelBottomItem(id: "test.terminal", title: "Terminal", ownerPluginID: "test") {
                AnyView(Text("terminal"))
            }
        ])
        #expect(rootView.view(for: .contentFooter) != nil)

        try plugin.onShutdown(kernel: kernel)
        #expect(rootView.view(for: .contentFooter) == nil)

        try plugin.onBoot(kernel: kernel)
        let relaunched = try #require(kernel.resolveProvider((any PanelBottomProviding).self))
        // 复用而非重建：旧入口仍在（若重建则为空），容器随之恢复安装。
        // 注：不用 `(existential as AnyObject) ===` 断言身份，该写法会触发
        // Swift 6.4 SILGenLazyConformance 编译器崩溃。
        #expect(relaunched.items.map(\.id) == ["test.terminal"])
        #expect(rootView.view(for: .contentFooter) != nil)

        try plugin.onShutdown(kernel: kernel)
    }
}
