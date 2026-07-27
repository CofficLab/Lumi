import Foundation
import LumiUI

/// Theme 服务
///
/// 提供主题贡献收集。LumiUI 中已经定义了 LumiUIThemeContribution / LumiUIThemeProviding。
public typealias LumiUIThemeContribution = LumiUI.LumiUIThemeContribution
public typealias LumiUIThemeProviding = LumiUI.LumiUIThemeProviding
public typealias LumiUIThemeRegistry = LumiUI.LumiUIThemeRegistry
public typealias ThemeSortKey = LumiUI.ThemeSortKey

/// Theme 服务协议
///
/// 由 Theme 插件实现,把主题注入到内核,并提供主题管理能力。
@MainActor
public protocol UIThemeProviding: AnyObject {
    /// 主题注册表
    var themeRegistry: LumiUIThemeRegistry { get }

    /// 所有已注册的主题贡献
    var themes: [LumiUIThemeContribution] { get }

    /// 当前选中主题 ID
    var selectedThemeId: String? { get }

    /// 当前选中主题贡献
    var selectedContribution: LumiUIThemeContribution? { get }

    /// 主题贡献
    func themeContributions() -> [LumiUIThemeContribution]

    /// 选择指定主题
    func selectTheme(id: String) throws

    /// 注册一个主题贡献
    func registerTheme(_ contribution: LumiUIThemeContribution)

    /// 注销一个主题贡献
    func unregisterTheme(id: String)

    /// 将内核持有的主题贡献同步到 LumiUI 的主题注册中心。
    ///
    /// 在 `LumiKernel.startup()` 末尾调用,确保所有插件的 `onReady` 已执行完毕、
    /// 主题贡献已注册到内核后,再统一同步到 LumiUI 的 `LumiUIThemeRegistry`。
    func syncToLumiUI()
}
