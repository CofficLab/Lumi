import Foundation
import KernelLumi
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// 设置插件
///
/// 提供 SettingsProviding 服务的默认实现。
/// 负责管理所有插件的设置标签项和 LLM 提供商设置项的注册和查询。
///
/// 同时贡献两个"应用基础设置"标签:General / Appearance。
/// 这些页面过去是 `LumiFactory` 硬编码的内置标签;现在统一改为由插件贡献(宿主层现归 FactoryCore),
/// 使设置界面的所有标签都走同一条 `settingsTabItems(kernel:)` 链路。
@MainActor
public final class SettingsPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.settings")
    nonisolated public static let emoji = "⚙️"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.settings"
    public var name: String {
        LumiPluginLocalization.string("Settings Plugin", bundle: .module)
    }
    public let order = 1
    public let policy: LumiPluginPolicy = .alwaysOn  // 核心插件，优先注册
    public let stage: LumiPluginStage = .beta

    // MARK: - State

    private var settingsService: DefaultSettingsProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: KernelLumi) async throws {
        try await SettingsOnBootHook().execute(kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        try SettingsOnReadyHook().execute(kernel)
    }

    // MARK: - Command Menu

    public func commandMenuGroups(kernel: KernelLumi) -> [CommandMenuGroup] {
        // 在应用菜单（Lumi 菜单，紧跟 "About"）中贡献 "Settings..." 命令，
        // 并绑定 macOS 约定快捷键 ⌘,。动作只发出 `.lumiOpenSettings` 通知，
        // 由主窗口根视图监听并打开设置窗口——这样命令闭包（非视图上下文）
        // 无需直接依赖 SwiftUI 的 `openWindow` 环境值。
        return [
            CommandMenuGroup(
                id: "\(id).commands",
                name: name,
                items: [
                    CommandItem(
                        id: "\(id).openSettings",
                        title: LumiPluginLocalization.string("Settings...", bundle: .module),
                        shortcut: ",",
                        modifiers: .command
                    ) {
                        NotificationCenter.default.post(name: .lumiOpenSettings, object: nil)
                    },
                ],
                placement: .appMenu
            ),
        ]
    }

    // MARK: - Settings Contributions

    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
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

    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
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

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        #if canImport(AppKit)
        // 设置入口位于标题工具栏最右侧；点击发出 `.lumiOpenSettings` 通知，
        // 由主窗口根视图监听并打开设置窗口——与上方 ⌘, 菜单命令走同一条链路，
        // 闭包无需依赖 SwiftUI 的 `openWindow` 环境值。
        return [
            LumiTitleToolbarItem(
                id: "\(id).openSettings",
                title: LumiPluginLocalization.string("Settings", bundle: .module),
                placement: .trailing,
                order: 1000
            ) {
                AppIconButton(
                    systemImage: "gearshape"
                ) {
                    NotificationCenter.default.post(name: .lumiOpenSettings, object: nil)
                }
            },
        ]
        #else
        // iOS 无标题工具栏：不贡献设置入口。
        return []
        #endif
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
