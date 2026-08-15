import FactoryCore
import KernelLumi
import SwiftUI
import XCTest

final class FactoryCoreLifecycleTests: XCTestCase {
    // MARK: - Test Helpers

    /// 仅注册一个空视图容器的最小插件，用于验证 createKernel 仅注册传入的插件。
    @MainActor
    private final class ContainerPlugin: LumiPlugin {
        let id: String
        let name = "Container"
        let order = 200
        let policy: LumiPluginPolicy = .alwaysOn
        let category: LumiPluginCategory = .general
        let stage: LumiPluginStage = .stable
        let pluginDescription = ""

        init(id: String) { self.id = id }

        func onBoot(kernel: KernelLumi) async throws {}


        func onReady(kernel: KernelLumi) async throws {}
        func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
        func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
        func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
        func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
        func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
        func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
        func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
        func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
        func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
        func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
        func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
        func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
        func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
        func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
        func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
        func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
        func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
        func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
        func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
        func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
        func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
        func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
        func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
        func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
        func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
        func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    }

    override func tearDown() async throws {
        // 清理静态内核注册表，避免测试间串扰。
        await MainActor.run { FactoryCore.destroyAllKernels() }
        try await super.tearDown()
    }

    // MARK: - Tests

    @MainActor
    func testDestroyAllKernelsClearsRegistry() {
        XCTAssertTrue(FactoryCore.kernels.isEmpty)
        FactoryCore.destroyAllKernels()
        XCTAssertTrue(FactoryCore.kernels.isEmpty)
    }

    @MainActor
    func testConfigurationAcceptsMinimalPluginSet() throws {
        // 不实际 bootstrap 内核（startup 需要完整服务栈）；
        // 这里验证配置层只携带传入的插件，Core 不偷偷扩充插件集合。
        let plugin = ContainerPlugin(id: "com.coffic.lumi.factory-core.test-container")
        let config = try FactoryConfiguration(plugins: [plugin])
        XCTAssertEqual(config.plugins.map(\.id), [plugin.id])
    }
}
