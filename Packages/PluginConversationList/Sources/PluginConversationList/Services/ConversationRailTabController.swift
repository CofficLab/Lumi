import KernelCore
import ProviderProject
import ProviderRailView
import SwiftUI

/// 对话列表侧栏标签（`chats` / `project-chats`）的动态可见性控制器。
///
/// 复刻旧版 ConversationListPlugin.ConversationRailTabController，适配新版
/// KernelCore / RailViewProviding 架构：
/// - `chats`：全库存在任意顶层对话时展示，否则不注册该标签；
/// - `project-chats`：全库顶层对话来自 ≥2 个项目且当前项目确有对话时展示。
///
/// 可见性在以下信号触发时重新评估（带去抖，避免一轮对话内反复查询 SQLite）：
/// - `.lumiConversationsDidChange`：对话增删 / 标题 / 项目迁移；
/// - `ProjectProviding` 的 `.currentProjectChanged` 语义事件：当前项目切换。
///
/// 所有评估均幂等：仅在期望状态与当前注册状态不一致时才执行 addTabs/removeTabs，
/// 因此事件回环会在下一次评估中收敛为空操作。
@MainActor
final class ConversationRailTabController {
    let chatsTabID: String
    let projectTabID: String

    /// 与插件 `order` 保持一致，使两个标签同序并排于插件所属位置。
    private let order: Int
    private let context: ConversationListContext
    private let attentionStore: ConversationAttentionStore
    private let sortStabilizer: ConversationSortStabilizer

    private weak var rail: (any RailViewProviding)?
    private var conversationsObserver: NSObjectProtocol?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    private var pendingRefresh: Task<Void, Never>?

    init(
        context: ConversationListContext,
        attentionStore: ConversationAttentionStore,
        sortStabilizer: ConversationSortStabilizer,
        order: Int,
        pluginID: String
    ) {
        self.context = context
        self.attentionStore = attentionStore
        self.sortStabilizer = sortStabilizer
        self.order = order
        self.chatsTabID = "\(pluginID).chats"
        self.projectTabID = "\(pluginID).project-chats"
    }

    /// 启动观察并执行首次评估。重复调用会刷新订阅（覆盖旧 token）。
    func start(rail: (any RailViewProviding)?) {
        self.rail = rail

        conversationsObserver = NotificationCenter.default.addObserver(
            forName: .lumiConversationsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleRefresh()
            }
        }

        if let project = context.project {
            projectObserver = project.addObserver { [weak self] event in
                guard case .currentProjectChanged = event else { return }
                self?.scheduleRefresh()
                }
        }

        // 首次评估负责按数据注册 `chats` / `project-chats`。
        scheduleRefresh()
    }

    /// 停止全部订阅并清空状态（插件卸载时调用）。
    func stop() {
        pendingRefresh?.cancel()
        pendingRefresh = nil
        if let conversationsObserver {
            NotificationCenter.default.removeObserver(conversationsObserver)
        }
        conversationsObserver = nil
        projectObserver?.cancel()
        projectObserver = nil
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
        // `chats`：全库顶层对话总数 >0 时才注册，避免出现空标签。
        let appCount = await context.conversations.conversationCount(projectPath: nil)
        reconcile(
            tabID: chatsTabID,
            desiredVisible: appCount > 0,
            item: makeChatsItem()
        )

        // `project-chats`：全库无对话时必然隐藏（短路，省去项目多样性查询）；
        // 否则沿用既有判定——全库 ≥2 个项目且当前项目确有对话。
        let projectTabVisible: Bool
        if appCount > 0, let path = context.currentProjectPath {
            let projectCount = await context.conversations.conversationProjectCount()
            // 项目数 <2 时无需再查当前项目对话数，直接隐藏。
            let currentCount = projectCount >= 2
                ? (await context.conversations.conversationCount(projectPath: path))
                : 0
            projectTabVisible = currentCount > 0
        } else {
            projectTabVisible = false
        }
        reconcile(
            tabID: projectTabID,
            desiredVisible: projectTabVisible,
            item: makeProjectItem()
        )
    }

    /// 将指定标签的注册状态收敛到 `desiredVisible`：需要时注册 `item`，不需要时注销。
    /// 幂等——状态已一致时为空操作。
    private func reconcile(tabID: String, desiredVisible: Bool, item: RailTabItem) {
        guard let rail else { return }
        let registered = rail.tabs.contains { $0.id == tabID }
        if desiredVisible && !registered {
            rail.addTabs([item])
        } else if !desiredVisible && registered {
            rail.removeTabs(ids: [tabID])
        }
    }

    // MARK: - Item Builders

    /// 构造 `chats` 标签项（`order` 显式设置以匹配插件排序——动态注册不经
    /// 插件的 order 赋值流程）。
    private func makeChatsItem() -> RailTabItem {
        let context = context
        let attentionStore = attentionStore
        let sortStabilizer = sortStabilizer
        return RailTabItem(
            id: chatsTabID,
            title: "对话",
            systemImage: "message.fill",
            order: order
        ) {
            RailView(
                context: context,
                attentionStore: attentionStore,
                sortStabilizer: sortStabilizer
            )
        }
    }

    /// 构造 `project-chats` 标签项。
    private func makeProjectItem() -> RailTabItem {
        let context = context
        let attentionStore = attentionStore
        let sortStabilizer = sortStabilizer
        return RailTabItem(
            id: projectTabID,
            title: "项目",
            systemImage: "folder.fill",
            order: order
        ) {
            RailView(
                context: context,
                attentionStore: attentionStore,
                sortStabilizer: sortStabilizer,
                scopeToCurrentProject: true
            )
        }
    }
}
