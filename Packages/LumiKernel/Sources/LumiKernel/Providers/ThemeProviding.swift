import Foundation
import LumiUI

/// Theme 服务
///
/// 提供主题贡献收集。LumiUI 中已经定义了 LumiUIThemeContribution / LumiUIThemeProviding。
public typealias LumiUIThemeContribution = LumiUI.LumiUIThemeContribution
public typealias LumiUIThemeProviding = LumiUI.LumiUIThemeProviding
public typealias ThemeSortKey = LumiUI.ThemeSortKey

/// Theme 贡献协议
///
/// 由 Theme 插件实现,把主题注入到内核。
@MainActor
public protocol UIThemeProviding: AnyObject {
    /// 主题贡献
    func themeContributions() -> [LumiUIThemeContribution]
}
