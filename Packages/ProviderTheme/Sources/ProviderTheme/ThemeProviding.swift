import Combine
import SwiftUI

// MARK: - Theme 能力协议

/// 主题管理能力协议。
///
/// 定义精简内核（KernelCore）需要的主题管理功能，由宿主装配时以
/// Provider 形式注入。插件 / 宿主通过 `registerTheme(_:)` 贡献主题，
/// 消费方（设置项、菜单、工具栏）订阅 `objectWillChange` 感知主题
/// 列表与选中状态变化，并调用 `selectTheme(id:)` 切换主题。
///
/// 复刻旧版 Lumi 的 `ThemeManagerPlugin` 能力：
/// - 主题贡献收集（注册 / 注销 / 全量替换）
/// - 选中与切换（校验主题 id）
/// - 选中状态持久化（由实现负责）
///
/// 采用与 `MenuBarProviding` / `LogoProviding` 一致的设计：协议只声明
/// 能力，不关心具体实现；使用 `AnyView` 无关的存在类型约束
/// （`any ThemeProviding`），可无泛型约束地注册进 KernelCore 的注册表。
///
/// 显式声明 `objectWillChange: ObservableObjectPublisher` 把
/// `ObservableObject` 的关联类型固定为具体类型，使 `any ThemeProviding`
/// 存在类型的 `objectWillChange` 可直接用于 `onReceive` / `sink`。
@MainActor
public protocol ThemeProviding: AnyObject, ObservableObject {
    /// 变更事件发布器（固定为 `ObservableObjectPublisher`，@Published 合成类型）。
    var objectWillChange: ObservableObjectPublisher { get }

    /// 全部已注册主题（按 `sortOrder` 升序）。
    var themes: [LumiTheme] { get }

    /// 当前选中主题 id。
    var selectedThemeId: String? { get }

    /// 当前选中主题。
    var selectedTheme: LumiTheme? { get }

    /// 当前选中主题是否跟随系统明暗（外观类型为 `.system`）。
    var followsSystemAppearance: Bool { get }

    /// 切换选中主题。主题 id 不存在时抛出 ``ThemeProvidingError.unknownThemeId``。
    func selectTheme(id: String) throws

    /// 注册主题贡献（同 id 覆盖，保留原排序位置）。
    func registerTheme(_ theme: LumiTheme)

    /// 注销主题贡献。若注销的是当前选中主题，回退到剩余主题的第一个。
    func unregisterTheme(id: String)

    /// 全量替换主题列表。空列表或重复 id 时抛出 ``ThemeProvidingError``；
    /// 替换后尽量保持当前选中，否则回退到第一个主题。
    func replaceAllThemes(_ themes: [LumiTheme]) throws
}

public extension ThemeProviding {
    /// 当前选中主题是否跟随系统明暗。
    var followsSystemAppearance: Bool {
        selectedTheme?.appearanceKind == .system
    }
}
