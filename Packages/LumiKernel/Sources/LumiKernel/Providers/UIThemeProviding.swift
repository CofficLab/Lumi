import Foundation

/// Theme 贡献协议
///
/// 由 Theme 插件实现,把主题注入到内核。
@MainActor
public protocol UIThemeProviding: AnyObject {
    /// 主题贡献
    func themeContributions() -> [LumiUIThemeContribution]
}
