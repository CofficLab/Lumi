import Combine
import SwiftUI

@MainActor
public enum ThemeProvidingEvent {
    /// 主题注册表发生变化（注册、注销或全量替换）。
    case themesChanged
    /// 当前选中主题发生变化；回调执行时 `selectedThemeId` 已是新值。
    case selectionChanged(themeID: String?)
}

@MainActor
public protocol ThemeProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 主题管理能力协议。
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

    /// 监听主题列表或当前选中主题变化。回调在状态更新完成后执行，
    /// 不应再通过 `objectWillChange` 读取“新”状态。
    @discardableResult
    func addObserver(_ callback: @escaping (ThemeProvidingEvent) -> Void) -> any ThemeProvidingObserverHandle

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
