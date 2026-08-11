import FactoryCore
import LumiKernel
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

        func onBoot(kernel: LumiKernel) async throws {}


        func onReady(kernel: LumiKernel) async throws {}
        func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
        func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
        func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
        func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
        func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
        func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
        func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
        func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
        func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
        func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
        func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
        func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
        func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
        func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
        func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
        func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
        func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
        func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
        func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
        func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
        func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
        func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
        func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
        func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
        func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
        func onContainerActivated(kernel: LumiKernel, containerID: String) {}
        func editorPlugins(kernel: LumiKernel) -> [any EditorPlugin] { [] }
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
