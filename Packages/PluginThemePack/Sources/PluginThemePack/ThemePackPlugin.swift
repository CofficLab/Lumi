import os
import KernelCore
import SuperLogKit
import ProviderSettingView
import ProviderTheme
import SwiftUI

/// 旧版主题插件集合的复刻包（单一插件批量注册 19 个主题 + 外观设置入口）。
///
/// 复刻自 LumiApp 的 17 个 `Theme*Plugin`（KernelLumi → KernelCore 适配）：
/// 精简内核（SuperPlugin）没有声明式贡献点，因此本插件在
/// `onBoot(kernel:)` 中主动解析 `ThemeProviding` 与 `SettingViewProviding`：
/// - 批量注册 `LegacyThemeCatalog.all`（19 个 `LumiTheme`，id 与旧版一致）；
/// - 注册「外观」设置入口，详情视图列出全部主题供切换。
///
/// 消费方（设置项、主窗口）通过 `ThemeProviding.themes` 读取全部主题
/// （内置 3 个 + 本插件 19 个），订阅 `objectWillChange` 感知切换。
@MainActor
public final class ThemePackPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.theme-pack", category: "ThemePack")

    public let id = "com.coffic.lumi.plugin.theme-pack"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.theme-pack",
        name: "主题包",
        description: "批量注册 19 个旧版主题，并在设置中提供外观切换入口。",
        category: .design,
        stage: .stable,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ThemeProviding from kernel")
            return
        }
        for legacy in LegacyThemeCatalog.all {
            theme.registerTheme(legacy)
        }

        // 设置入口：外观 / 主题选择（设置视图未注册时优雅降级）。
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.addEntries([
                SettingEntryItem(
                    id: "appearance",
                    title: "外观",
                    systemImage: "paintpalette",
                    order: 150
                ) {
                    ThemeSettingsDetailView(theme: theme)
                }
            ])
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let theme = kernel.resolveProvider((any ThemeProviding).self) {
            for legacy in LegacyThemeCatalog.all {
                theme.unregisterTheme(id: legacy.id)
            }
        }
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["appearance"])
    }
}
