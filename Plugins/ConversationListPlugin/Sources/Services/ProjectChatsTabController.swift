import Combine
import KernelLumi
import SwiftUI

/// 「当前项目对话」侧栏标签（`project-chats`）的动态可见性控制器。
///
/// 该标签不再通过 `panelRailTabItems` 静态注册，而是由本控制器按「当前项目是否存在对话」
/// 动态注册/注销：当前项目对话数为 0 时彻底隐藏入口，≥1 时自动出现。
///
/// 可见性在以下信号触发时重新评估（带去抖，避免一轮对话内反复查询 SQLite）：
/// - `.lumiConversationsDidChange`：对话增删 / 标题 / 项目迁移；
/// - `.workspaceContributionsDidChange`：插件 enable/disable 全量重建后兜底重注册；
/// - `kernel.project` 的 `objectWillChange`：当前项目切换。
///
/// 所有评估均幂等：仅在期望状态与当前注册状态不一致时才执行 register/unregister，
/// 因此事件回环（register/unregister 自身也会派发 `workspaceContributionsDidChange`）
/// 会在下一次评估中收敛为空操作。选中态的回退由 `RailTabBarView.ensureValidSelection()`
/// 在 `workspaceContributionsDidChange` 重载后自动处理，无需此处干预。
@MainActor
final class ProjectChatsTabController {
    static let tabID = "project-chats"

    /// 与插件 `order` 保持一致，使本标签与 `chats` 同序并排在其后。
    private let order: Int
    private let attentionStore: ConversationAttentionStore
    private let sortStabilizer: ConversationSortStabilizer

    private weak var kernel: KernelLumi?
    private var conversationsObserver: NSObjectProtocol?
    private var contributionsObserver: NSObjectProtocol?
    private var projectCancellable: AnyCancellable?
    private var pendingRefresh: Task<Void, Never>?

    init(attentionStore: ConversationAttentionStore,
         sortStabilizer: ConversationSortStabilizer,
         order: Int) {
        self.attentionStore = attentionStore
        self.sortStabilizer = sortStabilizer
        self.order = order
    }

    // 不实现 deinit：控制器由常驻插件（`.alwaysOn`）持有，生命周期等于 App，
    // 实践中不会析构。所有观察闭包均以 `[weak self]` 捕获——控制器释放后自动退化为
    // 空操作，Combine 订阅随 `projectCancellable` 一并释放，无循环引用。

    /// 启动观察并执行首次评估。重复调用会刷新订阅（覆盖旧 token）。
    func start(kernel: KernelLumi) {
        self.kernel = kernel

        conversationsObserver = NotificationCenter.default.onLumiConversationsDidChange { [weak self] in
            self?.scheduleRefresh()
        }

        contributionsObserver = NotificationCenter.default.addObserver(
            forName: KernelLumiEvent.workspaceContributionsDidChange.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRefresh()
        }

        if let project = kernel.project {
            projectCancellable = project.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.scheduleRefresh()
                }
        }

        scheduleRefresh()
    }

    /// 去抖调度：取消上一个待执行任务，延迟刷新。
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    /// 重新评估 `project-chats` 的注册状态并收敛到期望状态。
    private func refresh() async {
        guard let kernel, let workspace = kernel.workspace else { return }

        let desiredVisible: Bool
        if let path = kernel.project?.currentProject?.path {
            let count = await kernel.conversations?.conversationCount(projectPath: path) ?? 0
            desiredVisible = count > 0
        } else {
            desiredVisible = false
        }

        let registered = workspace.allPanelRailTabItems.contains { $0.id == Self.tabID }

        if desiredVisible && !registered {
            workspace.registerPanelRailTabItem(makeItem(kernel: kernel))
        } else if !desiredVisible && registered {
            workspace.unregisterPanelRailTabItem(id: Self.tabID)
        }
    }

    /// 构造与原静态定义一致的标签项（`order` 在此显式设置以匹配插件排序）。
    private func makeItem(kernel: KernelLumi) -> PanelRailTabItem {
        let attentionStore = attentionStore
        let sortStabilizer = sortStabilizer
        var item = PanelRailTabItem(
            id: Self.tabID,
            title: "Project",
            systemImage: "folder.fill",
            requiresProjectSupport: true,
            requiresChatSupport: true
        ) {
            RailView(kernel: kernel,
                     attentionStore: attentionStore,
                     sortStabilizer: sortStabilizer,
                     scopeToCurrentProject: true)
        }
        item.order = order
        return item
    }
}
