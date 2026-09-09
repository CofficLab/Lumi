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
    private var observers: [UUID: (MenuBarEvent) -> Void] = [:]

    public init() {}

    @discardableResult
    public func addMenuBarObserver(
        _ callback: @escaping (MenuBarEvent) -> Void
    ) -> any MenuBarObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func replaceContentItems(_ items: [MenuBarContentItem]) {
        contentItems = items
        notify(.contentItemsChanged)
    }

    public func replacePopupItems(_ items: [MenuBarPopupItem]) {
        popupItems = items
        notify(.popupItemsChanged)
    }

    private func notify(_ event: MenuBarEvent) {
        observers.values.forEach { $0(event) }
    }

    private final class ObserverHandle: MenuBarObserverHandle {
        private var cancellation: (() -> Void)?

        init(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation?()
            cancellation = nil
        }
    }
}
