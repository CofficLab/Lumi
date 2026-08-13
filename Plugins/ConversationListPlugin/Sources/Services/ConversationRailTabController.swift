import Combine
import KernelLumi
import SwiftUI

/// 会话列表侧栏标签（`chats` / `project-chats`）的动态可见性控制器。
///
/// 两个标签均不通过 `panelRailTabItems` 静态注册，而是由本控制器按对话存在情况
/// 动态注册/注销：
/// - `chats`：全库存在任意顶层对话时展示，否则彻底隐藏主入口；
/// - `project-chats`：全库顶层对话来自 ≥2 个项目且当前项目确有对话时展示。
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
final class ConversationRailTabController {
    static let chatsTabID = "chats"
    static let projectTabID = "project-chats"

    /// 与插件 `order` 保持一致，使两个标签同序并排于插件所属位置。
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

    /// 重新评估两个标签的注册状态并收敛到期望状态。
    private func refresh() async {
        guard let kernel, let workspace = kernel.workspace else { return }

        // `chats`：全库顶层对话总数 >0 时才展示——没有任何对话时隐藏主入口，
        // 避免一个只能打开空列表的侧栏标签。
        let appCount = await kernel.conversations?.conversationCount(projectPath: nil) ?? 0
        reconcile(
            tabID: Self.chatsTabID,
            desiredVisible: appCount > 0,
            item: makeChatsItem(kernel: kernel),
            workspace: workspace
        )

        // `project-chats`：全库无对话时必然隐藏（短路，省去项目多样性查询）；
        // 否则沿用既有判定——全库 ≥2 个项目且当前项目确有对话。
        let projectTabVisible: Bool
        if appCount > 0, let path = kernel.project?.currentProject?.path {
            let projectCount = await kernel.conversations?.conversationProjectCount() ?? 0
            // 项目数 <2 时无需再查当前项目对话数，直接隐藏。
            let currentCount = projectCount >= 2
                ? (await kernel.conversations?.conversationCount(projectPath: path) ?? 0)
                : 0
            projectTabVisible = currentCount > 0
        } else {
            projectTabVisible = false
        }
        reconcile(
            tabID: Self.projectTabID,
            desiredVisible: projectTabVisible,
            item: makeProjectItem(kernel: kernel),
            workspace: workspace
        )
    }

    /// 将指定标签的注册状态收敛到 `desiredVisible`：需要时注册 `item`，不需要时注销。
    /// 幂等——状态已一致时为空操作。
    private func reconcile(
        tabID: String,
        desiredVisible: Bool,
        item: PanelRailTabItem,
        workspace: any WorkspaceProviding
    ) {
        let registered = workspace.allPanelRailTabItems.contains { $0.id == tabID }
        if desiredVisible && !registered {
            workspace.registerPanelRailTabItem(item)
        } else if !desiredVisible && registered {
            workspace.unregisterPanelRailTabItem(id: tabID)
        }
    }

    // MARK: - Item Builders

    /// 构造 `chats` 标签项（`order` 显式设置以匹配插件排序——动态注册不经
    /// `panelRailTabItems` 的插件 order 赋值流程）。
    private func makeChatsItem(kernel: KernelLumi) -> PanelRailTabItem {
        let attentionStore = attentionStore
        let sortStabilizer = sortStabilizer
        var item = PanelRailTabItem(
            id: Self.chatsTabID,
            title: LumiPluginLocalization.string("Chats", bundle: .module),
            systemImage: "message.fill",
            requiresChatSupport: true
        ) {
            RailView(kernel: kernel, attentionStore: attentionStore, sortStabilizer: sortStabilizer)
        }
        item.order = order
        return item
    }

    /// 构造 `project-chats` 标签项。
    private func makeProjectItem(kernel: KernelLumi) -> PanelRailTabItem {
        let attentionStore = attentionStore
        let sortStabilizer = sortStabilizer
        var item = PanelRailTabItem(
            id: Self.projectTabID,
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
