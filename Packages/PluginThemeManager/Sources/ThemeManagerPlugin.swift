import Foundation
import KernelLumi
import LumiUI
import SwiftUI

// MARK: - Web API 响应模型

private struct ThemeListResponse: Encodable {
    struct Item: Encodable {
        let id: String
        let name: String
        let selected: Bool
    }
    let selectedThemeId: String?
    let themes: [Item]
}

private struct ThemeSwitchResponse: Encodable {
    let ok: Bool
    let currentThemeId: String
}

@MainActor
public final class ThemeManagerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme-manager"
    public var name: String {
        LumiPluginLocalization.string("Theme Manager", bundle: .module)
    }

    public let order = 22
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    private var themeService: ThemeManager?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        // Resolve the plugin data directory through StorageService so the file
        // lands at <dataRoot>/ThemeManager/theme-selection.plist instead of the
        // legacy <Application Support>/LumiUI/theme-selection.plist. See
        // ThemeSelectionStore for the StoragePlugin convention.
        let pluginDataDirectory = kernel.storage?.pluginDataDirectory(for: ThemeSelectionStore.pluginName)
        let themeSelectionStore = ThemeSelectionStore(pluginDataDirectory: pluginDataDirectory)
        let themeServiceInstance = ThemeManager()
        themeServiceInstance.setThemeSelectionStore(themeSelectionStore)
        try kernel.registerThemeService(themeServiceInstance)
        self.themeService = themeServiceInstance

        themeServiceInstance.setPluginManager(kernel.pluginManager)
        themeServiceInstance.setEventManager(kernel.eventManager)
    }

    public func onReady(kernel: KernelLumi) async throws {
        themeService?.setKernel(kernel)
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func commandMenuGroups(kernel: KernelLumi) -> [CommandMenuGroup] {
        guard let themeService else { return [] }
        return [themeService.commandMenuGroup()]
    }

    public func webRoutes(kernel: KernelLumi) -> [WebRoute] {
        // 主题服务在 onBoot 注册,webRoutes 收集时(startup step 13)已就绪。
        // 仅捕获 Sendable 的主题服务引用(非整个 kernel),供 @MainActor handler 使用。
        guard let theme = kernel.theme else { return [] }
        return [
            // GET /api/plugins/theme-manager/themes — 列出全部主题及当前选中。
            WebRoute(id: "theme-manager.themes", method: .get, path: "/api/plugins/theme-manager/themes", description: "列出全部主题及当前选中") { _ in
                let selected = theme.selectedThemeId
                let items = theme.themes.map {
                    ThemeListResponse.Item(id: $0.id, name: $0.displayName, selected: $0.id == selected)
                }
                return try .json(ThemeListResponse(selectedThemeId: selected, themes: items))
            },
            // POST /api/plugins/theme-manager/themes/:id/select — 切换到指定主题。
            WebRoute(id: "theme-manager.select", method: .post, path: "/api/plugins/theme-manager/themes/:id/select", description: "切换到指定主题") { request in
                guard let id = request.pathParameters["id"] else {
                    return try .json(["error": "missing theme id"], statusCode: 400)
                }
                do {
                    try theme.selectTheme(id: id)
                } catch {
                    return try .json(["error": error.localizedDescription], statusCode: 404)
                }
                return try .json(ThemeSwitchResponse(ok: true, currentThemeId: id))
            },
        ]
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(
            ThemeLandingPage(displayName: LumiPluginLocalization.string("Theme Manager", bundle: .module), icon: "paintpalette")
        )
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}

    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
}
