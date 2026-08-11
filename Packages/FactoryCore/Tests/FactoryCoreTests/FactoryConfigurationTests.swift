import FactoryCore
import LumiKernel
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
