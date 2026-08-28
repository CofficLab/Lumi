import SwiftUI

/// `MenuBarProviding` 的默认实现：持有内容项与弹窗项数组。
///
/// 插件通过 `addContent(_:)` / `addPopup(_:)` 追加自己的菜单栏贡献。
@MainActor
public final class DefaultMenuBarManager: MenuBarProviding, ObservableObject {
    /// 发布菜单栏贡献的变更，让宿主的 `MenuBarExtra` 在插件安装、卸载或
    /// 动态启停时同步刷新，而不只读取启动时的静态快照。
    @Published public private(set) var contentItems: [MenuBarContentItem] = []
    @Published public private(set) var popupItems: [MenuBarPopupItem] = []

    public init() {}

    public func replaceContentItems(_ items: [MenuBarContentItem]) {
        contentItems = items
    }

    public func replacePopupItems(_ items: [MenuBarPopupItem]) {
        popupItems = items
    }
}
