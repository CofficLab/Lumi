import FactoryCore
import KernelLumi
import SwiftUI
import XCTest

final class FactoryConfigurationTests: XCTestCase {
    // MARK: - Test Helpers

    /// 一个最小化的 `LumiPlugin` 实现，仅满足协议要求，用于配置校验测试。
    /// 不依赖任何具体生产插件，避免把插件包引入 FactoryCore 的测试依赖图。
    @MainActor
    private final class StubPlugin: LumiPlugin {
        let id: String
        let name: String
        let order: Int
        let policy: LumiPluginPolicy
        let category: LumiPluginCategory
        let stage: LumiPluginStage
        let pluginDescription: String

        init(
            id: String,
            name: String = "Stub",
            order: Int = 200,
            policy: LumiPluginPolicy = .alwaysOn,
            category: LumiPluginCategory = .general,
            stage: LumiPluginStage = .stable,
            pluginDescription: String = ""
        ) {
            self.id = id
            self.name = name
            self.order = order
            self.policy = policy
            self.category = category
            self.stage = stage
            self.pluginDescription = pluginDescription
        }

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

    @MainActor
    private func makePlugin(_ id: String) -> StubPlugin { StubPlugin(id: id) }

    // MARK: - Tests

    @MainActor
    func testAcceptsExplicitOrderedPluginArray() throws {
        let config = try FactoryConfiguration(plugins: [makePlugin("a"), makePlugin("b")])
        XCTAssertEqual(config.plugins.map(\.id), ["a", "b"])
    }

    @MainActor
    func testRejectsDuplicatePluginIDs() {
        XCTAssertThrowsError(try FactoryConfiguration(plugins: [makePlugin("dup"), makePlugin("dup")])) { error in
            guard case .duplicatePluginID(let id) = error as? FactoryConfigurationError else {
                return XCTFail("Expected duplicatePluginID, got \(error)")
            }
            XCTAssertEqual(id, "dup")
        }
    }

    @MainActor
    func testRejectsEnabledIDsNotInPluginArray() {
        let plugin = makePlugin("present")
        XCTAssertThrowsError(
            try FactoryConfiguration(plugins: [plugin], enabledPluginIDs: ["present", "missing"])
        ) { error in
            guard case let .unknownEnabledPluginIDs(unknown) = error as? FactoryConfigurationError else {
                return XCTFail("Expected unknownEnabledPluginIDs, got \(error)")
            }
            XCTAssertEqual(unknown, ["missing"])
        }
    }

    @MainActor
    func testAcceptsEnabledIDsSubsetOfPlugins() throws {
        let config = try FactoryConfiguration(
            plugins: [makePlugin("a"), makePlugin("b")],
            enabledPluginIDs: ["b"]
        )
        XCTAssertEqual(config.enabledPluginIDs, ["b"])
    }

    @MainActor
    func testPreservesDisplayFields() throws {
        let config = try FactoryConfiguration(
            plugins: [makePlugin("a")],
            initialContainerID: "container-a",
            showsStatusBar: false,
            showsActivityBar: false
        )
        XCTAssertEqual(config.initialContainerID, "container-a")
        XCTAssertFalse(config.showsStatusBar)
        XCTAssertFalse(config.showsActivityBar)
    }
}
