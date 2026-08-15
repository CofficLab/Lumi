import FactoryCore
import KernelLumi
import SwiftUI
import XCTest
@testable import FactoryLumi

/// Minimal no-op plugin used to exercise host-injected `additionalPlugins`.
@MainActor
private final class StubInjectedPlugin: LumiPlugin {
    let id = "com.coffic.lumi.tests.stub-injected"
    let name = "Stub Injected"
    let order = 900
    let policy: LumiPluginPolicy = .alwaysOn
    let stage: LumiPluginStage = .beta

    func onBoot(kernel: KernelLumi) async throws {}
    func onReady(kernel: KernelLumi) async throws {}
    func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] { [] }
    func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    func commandMenuGroups(kernel: KernelLumi) -> [CommandMenuGroup] { [] }
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
final class FactoryLumiFacadeTests: XCTestCase {
    func testDefaultConfigurationPointsAtChatPanel() {
        let configuration = FactoryLumi.configuration()
        XCTAssertEqual(configuration.initialContainerID, "com.coffic.lumi.plugin.chat-panel")
        XCTAssertEqual(configuration.plugins.count, LumiPluginCatalog.plugins.count)
        XCTAssertTrue(configuration.enabledPluginIDs.isEmpty)
        XCTAssertTrue(configuration.showsStatusBar)
        XCTAssertTrue(configuration.showsActivityBar)
    }

    func testIDSelectionRejectsEnabledIDsOutsideAllowlist() {
        let allowlist: Set<String> = ["com.coffic.lumi.plugin.storage"]
        XCTAssertThrowsError(
            try FactoryLumi.configuration(
                allowingIDs: allowlist,
                enabledPluginIDs: ["com.coffic.lumi.plugin.projects"]
            )
        ) { error in
            guard case FactoryConfigurationError.unknownEnabledPluginIDs = error else {
                return XCTFail("expected unknownEnabledPluginIDs, got \(error)")
            }
        }
    }

    func testAdditionalPluginsAreAppendedToCatalog() {
        let stub = StubInjectedPlugin()
        let configuration = FactoryLumi.configuration(additionalPlugins: [stub])
        let ids = configuration.plugins.map(\.id)
        XCTAssertEqual(ids.count, LumiPluginCatalog.plugins.count + 1)
        XCTAssertEqual(ids.last, stub.id, "host-injected plugins must come after the built-in catalog")
    }

    func testWindowAndCommandConstructorsDoNotCrash() {
        _ = FactoryLumi.makeMainWindow()
        _ = FactoryLumi.makeSettingsWindow()
        _ = FactoryLumi.makeCommands()
    }
}
