import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 设置插件
///
/// 提供 SettingsProviding 服务的默认实现。
/// 负责管理所有插件的设置标签项和 LLM 提供商设置项的注册和查询。
///
/// 同时贡献两个"应用基础设置"标签:General / Appearance。
/// 这些页面过去是 `LumiFactory` 硬编码的内置标签;现在统一改为由插件贡献,
/// 使设置界面的所有标签都走同一条 `settingsTabItems(kernel:)` 链路。
@MainActor
public final class SettingsPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.settings")
    nonisolated public static let emoji = "⚙️"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.settings"
    public let name = "Settings Plugin"
    public let order = 1
    public let policy: LumiPluginPolicy = .alwaysOn  // 核心插件，优先注册

    // MARK: - State

    private var settingsService: DefaultSettingsProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {
        try await SettingsOnBootHook().execute(kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {
        try SettingsOnReadyHook().execute(kernel)
    }

    // MARK: - Settings Contributions

    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: "app.general",
                title: LumiPluginLocalization.string("General", bundle: .module),
                systemImage: "gearshape",
                order: 0
            ) {
                GeneralSettingsView()
            },
            SettingsTabItem(
                id: "app.appearance",
                title: LumiPluginLocalization.string("Appearance", bundle: .module),
                systemImage: "paintbrush",
                order: 1
            ) {
                AppearanceSettingsView(kernel: kernel)
            },
        ]
    }

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Text(LumiPluginLocalization.string("Settings Plugin", bundle: .module))
                    .font(.headline)
                Text(LumiPluginLocalization.string(
                    "Provides the General and Appearance settings tabs.",
                    bundle: .module
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        )
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
