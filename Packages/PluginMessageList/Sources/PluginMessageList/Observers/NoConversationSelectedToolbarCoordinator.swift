import Combine
import ProviderProject
import ProviderToolbar

/// 管理无选中会话空态对工具栏分类的临时隐藏请求。
///
/// 空态本身提供“添加项目”入口；当应用还没有任何项目时，项目工具栏控件
/// 没有可管理的内容，因此只在空态存活期间隐藏 `.project` 分类。ActivityBar
/// 仍然负责设置基础上下文，ToolbarProviding 会将两者合并。
@MainActor
final class NoConversationSelectedToolbarCoordinator: ObservableObject {
    static let source = "com.coffic.lumi.plugin.message-list.no-conversation-empty-state"

    private let project: (any ProjectProviding)?
    private let toolbar: (any ToolbarProviding)?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    private var isActive = false

    init(
        project: (any ProjectProviding)?,
        toolbar: (any ToolbarProviding)?
    ) {
        self.project = project
        self.toolbar = toolbar
        projectObserver = project?.addObserver { [weak self] _ in
            self?.refresh()
        }
    }

    func activate() {
        isActive = true
        refresh()
    }

    func deactivate() {
        isActive = false
        toolbar?.setHiddenCategories([], for: Self.source)
    }

    private func refresh() {
        guard isActive else { return }
        let shouldHideProjectCategory = project?.projects.isEmpty == true
        toolbar?.setHiddenCategories(
            shouldHideProjectCategory ? [.project] : [],
            for: Self.source
        )
    }

}
