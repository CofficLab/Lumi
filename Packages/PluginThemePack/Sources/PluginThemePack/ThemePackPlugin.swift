import KernelCore
import ProviderTheme

/// 旧版主题插件集合的复刻包（单一插件批量注册 19 个主题）。
///
/// 复刻自 LumiApp 的 17 个 `Theme*Plugin`（KernelLumi → KernelCore 适配）：
/// 精简内核（SuperPlugin）没有 `registerTheme` 声明式贡献点，因此本插件在
/// `onBoot(kernel:)` 中主动解析 `ThemeProviding`，批量注册
/// `LegacyThemeCatalog.all`（19 个 `LumiTheme`，id 与旧版一致）。
///
/// 消费方（设置项、菜单、工具栏）通过 `ThemeProviding.themes` 读取全部
/// 主题（内置 3 个 + 本插件 19 个），订阅 `objectWillChange` 感知切换。
@MainActor
public final class ThemePackPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.theme-pack"
    public let order = 100

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else {
            return
        }
        for legacy in LegacyThemeCatalog.all {
            theme.registerTheme(legacy)
        }
    }
}
