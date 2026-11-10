import KernelCore
import LumiThemePack
import LumiLoggingKit
import os
import ProviderCommand
import ProviderDocsView
import ProviderSettingView
import ProviderTheme
import SwiftUI

/// 旧版主题插件集合的复刻包（单一插件批量注册主题 + 外观设置入口）。
///
/// 复刻自 LumiApp 的 17 个 `Theme*Plugin`（KernelLumi → KernelCore 适配）：
/// 精简内核（SuperPlugin）没有声明式贡献点，因此本插件在
/// `onBoot(kernel:)` 中主动解析 `ThemeProviding` 与 `SettingViewProviding`：
/// - 批量注册 `LumiThemeCatalog` 中的主题（id 与旧版一致）；
/// - 注册「外观」设置入口，详情视图列出全部主题供切换；
/// - 注册主题切换菜单（内核无 `CommandProviding` 时自动降级）；
/// - 注册「关于」页（内核无 `DocsViewProviding` 时自动降级）。
///
/// 支持宿主按需配置 `id` / `order` / `policy` / `themeIDs`，
/// 元数据与界面文案全部本地化。
/// `themeIDs` 为 `nil` 时加载全部目录主题（默认）；传入白名单时只加载
/// 白名单内的主题，「外观」设置页与主题菜单随之只展示该子集。
/// 消费方（设置项、主窗口）通过 `ThemeProviding.themes` 读取实际生效的主题
/// （内置主题 + 本插件注册的主题），订阅主题事件感知切换。
@MainActor
public final class ThemePackPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.theme-pack", category: "ThemePack")

    public let id: String
    public let order: Int
    public let metadata: PluginMetadata

    /// 宿主指定的主题 id 白名单；`nil` 表示加载全部目录主题。
    public let themeIDs: [String]?

    /// 实际生效的主题集合（按目录顺序）。
    public let themes: [LumiTheme]

    /// 创建主题包插件。
    ///
    /// - Parameters:
    ///   - id: 插件唯一标识（同时决定 About 条目 id 与主题菜单组 id）。
    ///   - order: 加载顺序（数值越小越先 `onBoot`）。
    ///   - policy: 启用策略；`.required` / `.alwaysOn` 始终启动，
    ///     `.enabledByDefault` 允许宿主运行时启停（禁用时撤回全部贡献）。
    ///   - themeIDs: 主题 id 白名单；`nil`（默认）加载全部目录主题。
    ///     白名单外的 id 会被忽略，可用 `LumiThemeRegistration.unknownIDs(in:)` 校验。
    public init(
        id: String = "com.coffic.lumi.plugin.theme-pack",
        order: Int = 100,
        policy: PluginEnablePolicy = .required,
        themeIDs: [String]? = nil
    ) {
        self.id = id
        self.order = order
        self.themeIDs = themeIDs
        self.themes = LumiThemeRegistration.themes(for: themeIDs)
        self.metadata = PluginMetadata(
            id: id,
            name: LumiPluginLocalization.string("Theme Pack", bundle: .module),
            description: String(
                format: LumiPluginLocalization.string(
                    "Registers %lld themes and provides an appearance switcher in settings.",
                    bundle: .module
                ),
                Int64(self.themes.count)
            ),
            category: .design,
            stage: .stable,
            policy: policy
        )
    }

    // MARK: - 生命周期

    /// 目录型贡献：注册「关于」条目（无论插件是否启用；无 DocsView 内核时降级）。
    public func onRegister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.addAbout(
            DocsEntry(id: id, name: metadata.name) { ThemePackAboutView(themeCount: self.themes.count) }
        )
    }

    /// 撤回 `onRegister` 的「关于」条目。
    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        registerContributions(kernel: kernel)
    }

    /// 运行时启用（`.enabledByDefault` 插件从禁用恢复时调用）。
    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerContributions(kernel: kernel)
    }

    /// 运行时禁用：撤回主题、设置入口与菜单。
    ///
    /// 直接注册进共享 Provider 的贡献不受内核自动撤回，
    /// 需在此显式注销（`addEntries` / `registerCommandGroup` / `registerTheme`
    /// 均按 id 幂等，重复撤回无副作用）。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        unregisterContributions(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        unregisterContributions(kernel: kernel)
    }

    // MARK: - 贡献注册

    private func registerContributions(kernel: KernelCoreContainer) {
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ThemeProviding from kernel")
            return
        }
        LumiThemeRegistration.register(in: theme, themeIDs: themeIDs)

        // 命令菜单：内核无 CommandProviding 时优雅降级。
        if let commands = kernel.resolveProvider((any CommandProviding).self) {
            commands.registerCommandGroup(makeCommandGroup(theme: theme))
        }

        // 设置入口：外观 / 主题选择（设置视图未注册时优雅降级）。
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.addEntries([
                SettingEntryItem(
                    id: Self.settingsEntryID,
                    title: LumiPluginLocalization.string("Appearance", bundle: .module),
                    systemImage: "paintpalette",
                    order: 2,
                    group: Self.settingsGroup
                ) {
                    ThemeSettingsDetailView(theme: theme)
                },
            ])
        }
    }

    private func unregisterContributions(kernel: KernelCoreContainer) {
        kernel.resolveProvider((any CommandProviding).self)?
            .unregisterCommandGroup(id: commandGroupID)
        if let theme = kernel.resolveProvider((any ThemeProviding).self) {
            LumiThemeRegistration.unregister(from: theme, themeIDs: themeIDs)
        }
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: [Self.settingsEntryID])
    }

    // MARK: - 私有

    private static let settingsEntryID = "appearance"

    /// iOS 根页分组：外观。分组标题与入口标题共用同一份本地化文案。
    private static let settingsGroup = SettingEntryGroup(
        id: "appearance",
        title: LumiPluginLocalization.string("Appearance", bundle: .module),
        order: 10
    )

    /// 菜单组 id 派生自插件 id，保证多实例/多应用互不冲突。
    private var commandGroupID: String { "\(id).theme.menu" }

    static func localizedMenuName(locale: Locale = .current) -> String {
        LumiPluginLocalization.string("Theme", bundle: .module, locale: locale)
    }

    private func makeCommandGroup(theme: any ThemeProviding) -> CommandMenuGroup {
        CommandMenuGroup(
            id: commandGroupID,
            name: Self.localizedMenuName(),
            items: theme.themes.map { item in
                CommandItem(
                    id: "\(commandGroupID).select.\(item.id)",
                    title: item.displayName,
                    stateProvider: {
                        theme.selectedThemeId == item.id ? .on : .off
                    }
                ) {
                    try? theme.selectTheme(id: item.id)
                }
            },
            placement: .topLevelMenu
        )
    }
}
