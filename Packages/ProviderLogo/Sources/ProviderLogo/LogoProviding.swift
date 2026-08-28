import SwiftUI

// MARK: - Logo Capability Protocol

/// Logo 能力协议
///
/// 定义精简内核（KernelCore）需要的 Logo 管理功能，由宿主装配时
/// 以 Provider 形式注入。插件通过该协议注册 / 注销自己贡献的 Logo 项，
/// 消费方（如菜单栏图标）按优先级取用。
///
/// 采用与 `MenuBarProviding` 一致的设计：协议只声明能力，不关心具体实现；
/// 使用 `AnyView` 而非 `associatedtype`，可无泛型约束地作为存在类型
/// （`any LogoProviding`）注册进 KernelCore 的注册表。
@MainActor
public protocol LogoProviding: AnyObject, ObservableObject {
    /// Whether the currently displayed Logo should use its highlighted status-bar presentation.
    var isLogoHighlighted: Bool { get }

    /// Changes the highlighted state used by status-bar Logo consumers.
    func setLogoHighlighted(_ highlighted: Bool)

    /// 所有已注册的 Logo 项（按优先级降序）
    var allLogoItems: [LogoItem] { get }

    /// 注册 Logo 项
    func registerLogoItem(_ item: LogoItem)

    /// 注销 Logo 项
    func unregisterLogoItem(id: String)

    /// 清空所有插件贡献（供全量重建使用）。默认 no-op。
    func clearAllContributions()
}

public extension LogoProviding {
    /// 当前最高优先级的 Logo 项。
    var highestPriorityLogoItem: LogoItem? {
        allLogoItems.max { $0.order < $1.order }
    }

    func clearAllContributions() {}
}
