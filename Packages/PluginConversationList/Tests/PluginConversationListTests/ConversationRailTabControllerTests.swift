import Foundation
import ProviderConversation
import ProviderProject
import ProviderRailView
import ProviderRootView
import Testing
@testable import PluginConversationList

@Test @MainActor func railTabsFollowConversationAndCurrentProjectAvailability() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/One")
    let context = makeContext(conversations: conversations, project: project)
    let attentionStore = ConversationAttentionStore()
    let sortStabilizer = ConversationSortStabilizer()
    let chatsViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .all)
    let projectViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .currentProject)
    let controller = ConversationRailTabController(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: sortStabilizer,
        chatsViewModel: chatsViewModel,
        projectViewModel: projectViewModel,
        order: 81,
        pluginID: "test.conversation-list"
    )
    let rail = DefaultRailViewProviding()
    controller.start(rail: rail)
    try await Task.sleep(for: .milliseconds(120))
    #expect(rail.tabs.isEmpty)

    let firstID = try conversations.createConversation(title: "One", projectPath: "/workspace/One", providerID: nil, modelName: nil)
    let chatsTabID = "test.conversation-list.chats"
    let projectTabID = "test.conversation-list.project-chats"
    let firstConversationRegistered = await waitUntil { rail.tabs.contains { $0.id == chatsTabID } }
    #expect(firstConversationRegistered)
    #expect(!rail.tabs.contains { $0.id == projectTabID })

    let secondID = try conversations.createConversation(title: "Two", projectPath: "/workspace/Two", providerID: nil, modelName: nil)
    let projectConversationRegistered = await waitUntil { rail.tabs.contains { $0.id == projectTabID } }
    #expect(projectConversationRegistered)

    try await project.openProject(at: "/workspace/Three")
    let projectTabRemovedWhenCurrentProjectIsEmpty = await waitUntil { !rail.tabs.contains { $0.id == projectTabID } }
    #expect(projectTabRemovedWhenCurrentProjectIsEmpty)
    try await project.openProject(at: "/workspace/Two")
    let projectTabRestoredForCurrentProject = await waitUntil { rail.tabs.contains { $0.id == projectTabID } }
    #expect(projectTabRestoredForCurrentProject)

    conversations.deleteConversation(id: secondID)
    let projectTabRemovedWhenOnlyOneProjectRemains = await waitUntil { !rail.tabs.contains { $0.id == projectTabID } }
    #expect(projectTabRemovedWhenOnlyOneProjectRemains)
    conversations.deleteConversation(id: firstID)
    let chatsTabRemovedWhenLibraryIsEmpty = await waitUntil { !rail.tabs.contains { $0.id == chatsTabID } }
    #expect(chatsTabRemovedWhenLibraryIsEmpty)

    controller.stop()
}

@Test @MainActor func stoppingRailControllerCancelsRefreshSubscriptions() async throws {
    let conversations = DefaultConversationManager()
    let context = makeContext(conversations: conversations)
    let attentionStore = ConversationAttentionStore()
    let sortStabilizer = ConversationSortStabilizer()
    let chatsViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .all)
    let projectViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .currentProject)
    let controller = ConversationRailTabController(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: sortStabilizer,
        chatsViewModel: chatsViewModel,
        projectViewModel: projectViewModel,
        order: 81,
        pluginID: "test.conversation-list"
    )
    let rail = DefaultRailViewProviding()
    controller.start(rail: rail)
    try await Task.sleep(for: .milliseconds(120))
    controller.stop()

    _ = try conversations.createConversation(title: "After stop", projectPath: nil, providerID: nil, modelName: nil)
    try await Task.sleep(for: .milliseconds(120))

    #expect(rail.tabs.isEmpty)
}

/// `reconcile` 会把 Rail 栏可见性写回宿主（`setRailViewVisible(hasVisibleTabs)`），
/// 而既有测试都只传了 `rail`、没传 `rootView`，这条写入路径从未被断言过。
///
/// ## 为什么这条路径值得单独钉住
///
/// 全新安装时 Rail 栏的可见性被**两个插件同时写**：
/// - `ChatPanelPlugin` 在 `onBoot` 末尾无条件 `setRailViewVisible(true)`；
/// - `ConversationRailTabController.refresh` 在无任何对话时按
///   `hasVisibleTabs == false` 写回 `false`。
///
/// 二者靠 `ChatPanelPlugin` 的 `rootViewObserver` 监听
/// `.railViewVisibilityChanged(false)` 再顶回 `true` 才不打架。这条「顶回」
/// 是异步观察者驱动的，只在真实启动顺序（插件 boot → 宿主绑定）下才成立。
/// 若它失效，新用户首屏左侧栏会整条消失，且不报任何错。
@Test @MainActor func railVisibilityIsWrittenBackToHostOnEveryReconcile() async throws {
    let conversations = DefaultConversationManager()
    let context = makeContext(conversations: conversations)
    let attentionStore = ConversationAttentionStore()
    let sortStabilizer = ConversationSortStabilizer()
    let chatsViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .all)
    let projectViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .currentProject)
    let controller = ConversationRailTabController(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: sortStabilizer,
        chatsViewModel: chatsViewModel,
        projectViewModel: projectViewModel,
        order: 81,
        pluginID: "test.conversation-list"
    )
    let rail = DefaultRailViewProviding()
    let rootView = DefaultRootViewProviding()
    // 模拟 ChatPanelPlugin 首屏写入的 `true`：真实顺序里 Chat 先 boot。
    rootView.setRailViewVisible(true)

    controller.start(rail: rail, rootView: rootView)
    try await Task.sleep(for: .milliseconds(120))

    // 无对话 → 无可见 tab → 宿主可见性必须被拉下来。
    // 这一步是本测试的核心：若 `reconcile` 忘记写回，`rootView` 会停在 true，
    // 「空 Rail 栏」就会被渲染出来。
    #expect(!rail.hasVisibleTabs)
    #expect(
        !rootView.isRailViewVisible,
        "无任何可见 tab 时宿主 Rail 可见性未被写回为 false —— 全新用户会看到一条空侧栏"
    )

    // 产生第一个对话 → tab 注册 → 宿主可见性必须同步拉回 true。
    _ = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let becameVisible = await waitUntil { rootView.isRailViewVisible }
    #expect(becameVisible, "出现可见 tab 后宿主 Rail 可见性未同步为 true")
    #expect(rail.hasVisibleTabs)

    // 删除最后一个对话 → 再次写回 false（幂等收敛，不应卡在 true）。
    let only = try #require(conversations.sortedConversations.first?.id)
    conversations.deleteConversation(id: only)
    let hiddenAgain = await waitUntil { !rootView.isRailViewVisible }
    #expect(hiddenAgain, "清空对话后宿主 Rail 可见性未回落，空栏会残留在界面上")

    controller.stop()
}

@MainActor
private func makeContext(
    conversations: any ConversationManaging,
    project: (any ProjectProviding)? = nil
) -> ConversationListContext {
    ConversationListContext(
        conversations: conversations,
        project: project,
        agentTurn: nil,
        conversationState: nil,
        chat: nil
    )
}

@MainActor
private func makeViewModel(
    context: ConversationListContext,
    attentionStore: ConversationAttentionStore,
    sortStabilizer: ConversationSortStabilizer,
    scope: ConversationListViewModel.Scope
) -> ConversationListViewModel {
    ConversationListViewModel(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: sortStabilizer,
        scope: scope
    )
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}
