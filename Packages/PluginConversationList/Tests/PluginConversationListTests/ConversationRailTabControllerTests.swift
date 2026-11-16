import Foundation
import ProviderConversation
import ProviderProject
import ProviderRailView
import PluginRootView
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

/// #931：只有一个项目路径，但库里还有无项目会话时，两个范围仍不同，
/// 「项目」标签必须出现，且项目列表只包含当前项目的会话。
@Test @MainActor func railProjectTabAppearsWhenOnlyProjectlessConversationsDiffer() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    // 未打开项目时创建的会话保持 projectPath == nil。
    _ = try conversations.createConversation(title: "Loose", projectPath: nil, providerID: nil, modelName: nil)
    try await project.openProject(at: "/workspace/Only")
    let onlyID = try conversations.createConversation(title: "Only", projectPath: "/workspace/Only", providerID: nil, modelName: nil)

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
    defer { controller.stop() }

    let projectTabID = "test.conversation-list.project-chats"
    let projectTabRegistered = await waitUntil { rail.tabs.contains { $0.id == projectTabID } }
    #expect(projectTabRegistered)

    await projectViewModel.loadInitialIfNeeded()
    #expect(projectViewModel.conversations.map(\.id) == [onlyID])
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
    let rootView = PluginRootView.DefaultRootViewProvider()
    // 模拟 ChatPanelPlugin 首屏写入的 `true`：真实顺序里 Chat 先 boot。
    rootView.setRailViewVisible(true)

    controller.start(rail: rail, rootView: rootView)
    // 等首次 reconcile 收敛，而不是固定睡 120ms。
    //
    // - Important: 固定 sleep 在高负载下（CI 上多个包同时跑）不够 ——
    //   reconcile 还没跑完就断言，读到的是「尚未写回」的中间状态 →
    //   **偶发**失败。改成条件等待：条件成立即返回。
    // 等首次 reconcile 把宿主可见性写回 false，而不是固定睡 120ms。
    //
    // - Important: `scheduleRefresh` 自带 80ms 去抖延迟，加上实际的
    //   对话计数查询，高负载下（CI 上多个包同时跑）固定 120ms 不足以
    //   等到 reconcile 完成 → 读到「尚未写回」的中间状态 → **偶发**失败。
    //
    //   判据是**写回结果本身**（宿主可见性变为 false），而不是
    //   `rail.hasVisibleTabs`（它一开始就是 false，立即满足，等不到任何东西）。
    let reconciled = await waitUntil(timeout: .seconds(10)) { !rootView.isRailViewVisible }
    #expect(reconciled, "首次 reconcile 未把宿主 Rail 可见性写回 false")

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

/// #923：Rail 标签的 `title` 会被宿主 `AppTabBar` 直接用作 `.help(title)`，
/// 也就是鼠标悬停 tooltip。标题必须走插件本地化，不能写死中文。
@Test @MainActor func railTabTitlesUsePluginLocalization() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    _ = try conversations.createConversation(title: "Loose", projectPath: nil, providerID: nil, modelName: nil)
    try await project.openProject(at: "/workspace/Only")
    _ = try conversations.createConversation(title: "Only", projectPath: "/workspace/Only", providerID: nil, modelName: nil)

    let context = makeContext(conversations: conversations, project: project)
    let attentionStore = ConversationAttentionStore()
    let sortStabilizer = ConversationSortStabilizer()
    let controller = ConversationRailTabController(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: sortStabilizer,
        chatsViewModel: makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .all),
        projectViewModel: makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .currentProject),
        order: 81,
        pluginID: "test.conversation-list",
        localizedTitle: { key in "localized:\(key)" }
    )
    let rail = DefaultRailViewProviding()
    controller.start(rail: rail)
    defer { controller.stop() }

    let chatsTabID = "test.conversation-list.chats"
    let projectTabID = "test.conversation-list.project-chats"
    #expect(await waitUntil { rail.tabs.contains { $0.id == chatsTabID } })
    #expect(await waitUntil { rail.tabs.contains { $0.id == projectTabID } })

    let chatsTab = try #require(rail.tabs.first { $0.id == chatsTabID })
    let projectTab = try #require(rail.tabs.first { $0.id == projectTabID })
    // 两个标题都必须来自本地化解析，而不是写死字面量。
    #expect(chatsTab.title == "localized:Chats")
    #expect(projectTab.title == "localized:Projects")
}

/// 标签标题依赖的两个 key 必须真的存在于插件字符串表中，且随语言切换。
@Test func railTabTitleKeysHaveTranslations() throws {
    #expect(try compiledStrings(language: "en")["Chats"] == "Chats")
    #expect(try compiledStrings(language: "en")["Projects"] == "Projects")
    #expect(try compiledStrings(language: "zh-Hans")["Chats"] == "对话")
    #expect(try compiledStrings(language: "zh-Hans")["Projects"] == "项目")
    #expect(try compiledStrings(language: "zh-Hant")["Projects"] == "專案")
    #expect(try compiledStrings(language: "zh-TW")["Projects"] == "專案")
}

/// #1170：被取消的旧刷新晚到后，不得移除新刷新刚注册的 Chats 标签。
@Test @MainActor func cancelledRefreshDoesNotRemoveNewerRailTabs() async throws {
    let conversations = GatedCountConversationManager()
    conversations.gateNextCount = true
    let context = makeContext(conversations: conversations)
    let attentionStore = ConversationAttentionStore()
    let sortStabilizer = ConversationSortStabilizer()
    let controller = ConversationRailTabController(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: sortStabilizer,
        chatsViewModel: makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .all),
        projectViewModel: makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .currentProject),
        order: 81,
        pluginID: "test.conversation-list"
    )
    let rail = DefaultRailViewProviding()
    controller.start(rail: rail)
    defer { controller.stop() }

    // 旧刷新 A 进入全库计数查询并被门闩挂起，此刻快照为 0。
    while conversations.countGate == nil { await Task.yield() }

    // 创建第一条会话触发刷新 B；B 读到 1 并注册 Chats 标签。
    _ = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let chatsTabID = "test.conversation-list.chats"
    #expect(await waitUntil(timeout: .seconds(5)) { rail.tabs.contains { $0.id == chatsTabID } })

    // 释放 A：它带着旧快照 0 返回，不得移除 B 注册的标签。
    conversations.countGate?.resume()
    conversations.countGate = nil
    try await Task.sleep(for: .milliseconds(200))
    #expect(rail.tabs.contains { $0.id == chatsTabID }, "被取消的旧刷新移除了新注册的 Chats 标签")
}

private func compiledStrings(language: String) throws -> [String: String] {
    let bundle = PluginConversationList.pluginLocalization.bundle
    let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
    let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
    return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
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

/// 全库计数查询可被门闩挂起的会话管理替身，用来构造「旧刷新晚到」的交错。
@MainActor
private final class GatedCountConversationManager: ConversationManaging {
    private var summaries: [ConversationSummary] = []
    private var observers: [UUID: (ConversationEvent) -> Void] = [:]

    /// 置 true 时下一次计数查询挂起，直到 `countGate` 被 resume。
    var gateNextCount = false
    var countGate: CheckedContinuation<Void, Never>?

    var conversations: [ConversationSummary] { summaries }
    var selectedConversationID: UUID? { nil }
    var currentTitle: String { "" }
    var dataDirectory: URL { URL(fileURLWithPath: "/tmp/PluginConversationListTests") }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?
    ) throws -> UUID {
        try createConversation(
            title: title,
            projectPath: projectPath,
            providerID: providerID,
            modelName: modelName,
            parentConversationID: nil
        )
    }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        let id = UUID()
        summaries.append(ConversationSummary(
            id: id, title: title ?? "New", createdAt: Date(), updatedAt: Date(), projectPath: projectPath
        ))
        notify(.created(id))
        return id
    }

    func conversationCount(projectPath: String?) async -> Int {
        // 请求发起时锁定快照，模拟存储层返回的是查询时刻的计数。
        let snapshot: Int
        if let projectPath {
            snapshot = summaries.filter { $0.projectPath == projectPath }.count
        } else {
            snapshot = summaries.count
        }
        if gateNextCount {
            gateNextCount = false
            await withCheckedContinuation { countGate = $0 }
        }
        return snapshot
    }

    func addConversationObserver(
        _ callback: @escaping (ConversationEvent) -> Void
    ) -> any ConversationObserverHandle {
        let token = UUID()
        observers[token] = callback
        return BlockObserverHandle { [weak self] in self?.observers[token] = nil }
    }

    private func notify(_ event: ConversationEvent) {
        for callback in observers.values { callback(event) }
    }

    func selectConversation(id: UUID) {}
    func deselectConversation() {}
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
    func markConversationActive(id: UUID, messageDate: Date) {}
    func isSending(for conversationID: UUID?) -> Bool { false }
    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}

    var globalVerbosity: ResponseVerbosity { .standard }
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { globalVerbosity }
    func setVerbosity(_ level: ResponseVerbosity, for conversationID: UUID?) {}
    func setGlobalVerbosity(_ level: ResponseVerbosity) {}

    var globalReasoningEffort: ReasoningEffort? { nil }
    func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort { .medium }
    func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? { nil }
    func setReasoningEffort(_ effort: ReasoningEffort, for conversationID: UUID?) {}
    func clearReasoningEffort(for conversationID: UUID?) {}
    func setGlobalReasoningEffort(_ effort: ReasoningEffort?) {}

    var globalAutomationLevel: AutomationLevel { .chat }
    func automationLevel(for conversationID: UUID?) -> AutomationLevel { globalAutomationLevel }
    func setAutomationLevel(_ level: AutomationLevel, for conversationID: UUID?) {}
    func setGlobalAutomationLevel(_ level: AutomationLevel) {}

    var globalLanguage: ConversationLanguage { .chinese }
    func language(for conversationID: UUID?) -> ConversationLanguage { globalLanguage }
    func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}
    func setGlobalLanguage(_ language: ConversationLanguage) {}

    func addSelectedConversationObserver(
        _ observer: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle {
        NoopSelectedConversationObserverHandle()
    }
}

@MainActor
private final class BlockObserverHandle: ConversationObserverHandle {
    private let onCancel: () -> Void
    init(_ onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() { onCancel() }
}
