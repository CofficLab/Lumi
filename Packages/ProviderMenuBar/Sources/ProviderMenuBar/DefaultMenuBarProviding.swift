import SwiftUI

/// `MenuBarProviding` 的默认实现：持有内容项与弹窗项数组。
///
/// 插件通过 `addContent(_:)` / `addPopup(_:)` 追加自己的菜单栏贡献。
@MainActor
public final class DefaultMenuBarProviding: MenuBarProviding {
    public private(set) var contentItems: [MenuBarContentItem] = []
    public private(set) var popupItems: [MenuBarPopupItem] = []

    public init() {}

    public func replaceContentItems(_ items: [MenuBarContentItem]) {
        contentItems = items
    }

    public func replacePopupItems(_ items: [MenuBarPopupItem]) {
        popupItems = items
    }
}
