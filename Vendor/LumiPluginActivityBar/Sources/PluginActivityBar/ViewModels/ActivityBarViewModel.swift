import Combine
import ProviderActivityBar

/// ActivityBar 视图唯一依赖的数据状态与交互入口。
///
/// Provider 的外部变化由 `PluginManagerObserver` 观察并通过 `refresh()` 写入；
/// View 只读取这里发布的状态，不直接读取或监听 Provider。
@MainActor
final class ActivityBarViewModel: ObservableObject {
    @Published private(set) var items: [ActivityBarItem] = []
    @Published private(set) var activeItemID: String?
    @Published private(set) var shouldDisplayActivityBar = false

    private weak var provider: (any ActivityBarProviding)?

    init(provider: any ActivityBarProviding) {
        self.provider = provider
        refresh()
    }

    /// 从 Provider 重新生成视图状态。
    func refresh() {
        guard let provider else {
            items = []
            activeItemID = nil
            shouldDisplayActivityBar = false
            return
        }

        items = provider.items
        activeItemID = provider.activeItemID
        shouldDisplayActivityBar = provider.shouldDisplayActivityBar
    }

    /// 由视图触发入口切换，实际状态变化仍由 Provider 事件回写到 VM。
    func activateItem(id: String?) {
        provider?.activateItem(id: id)
    }
}
