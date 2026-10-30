import Foundation
import KernelCore
import PluginChatPanel
import PluginConversationList
import PluginConversationManager
import PluginMessageListEmpty
import PluginMessageListStandard
import PluginMessageManager
import PluginToolbar
import ProviderActivityBar
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToolManager
import ProviderToolbar
import Testing

/// 「全新安装 → 首条消息 → 看到对话列表」这条用户旅程的装配级回归。
///
/// ## 为什么单包测试钉不住这条链路
///
/// 用户可见的现象横跨**三个独立插件**，它们各自只被别的测试单独覆盖过：
///
/// 1. `PluginMessageListEmpty`（`policy: .alwaysOn`）判定无消息 → 占 `message-list` 槽；
/// 2. `PluginMessageListStandard` 常驻同槽，靠 verbosity 参与竞争；
/// 3. `PluginConversationList` 监听 `.created`，注册 `chats` Rail tab 并写回
///    `rootView.setRailViewVisible(hasVisibleTabs)`；
/// 4. `PluginChatPanel` 首屏无条件 `setRailViewVisible(true)`，并在宿主绑定时
///    监听 `.railViewVisibilityChanged(false)` 把 Rail 顶回来。
///
/// 真正的失效模式恰恰在**接缝**上，而不在任一插件内部：
///
/// - 空态 `order = 81`、标准 `order = 82`，`exclusiveGroup` 仲裁**只看 order**
///   （`DefaultChatSectionProviding.exclusiveItems` 先按 order 排序再取每组首个）。
///   空态的 `isActive` 一旦误判为 true，它就会**永久压住**消息列表。
/// - Rail 可见性被 3 与 4 同时写。3 写 `hasVisibleTabs`（无对话时 false），
///   4 写 true。二者靠 4 的观察者收敛，若收敛失效，用户看到的是
///   「空侧栏」或「侧栏整条消失」，且**不产生任何错误日志**。
/// - 首次发消息的真实动作是 `createConversation` → 内部 `cache` + 自动
///   `selectedConversationID = id`。空态插件的观察者链必须跟到这一步。
///
/// 任何一条单插件测试都覆盖不到上面三点的交叉，因此这里跑**真实插件 + 真实
/// Provider** 的完整装配，用真实 Kernel 驱动，只对数据根目录做临时重定向。
@MainActor
@Suite("Fresh Install → First Message Assembly")
struct FreshInstallFirstMessageAssemblyTests {

    /// 全新安装首屏：空态占槽、消息列表让位、Rail 无可见 tab。
    @Test("全新安装首屏空态占槽且消息列表让位")
    func freshInstallShowsEmptyStateNotMessageList() async throws {
        let harness = try await FreshInstallHarness.make()

        // 空态确实在渲染（槽位被它占据）。
        #expect(
            harness.renderedMessageListItemID == harness.emptyPluginID,
            "全新安装首屏应渲染空态引导页，实际渲染 \(harness.renderedMessageListItemID ?? "nil")"
        )
        // 反向证据：排除「两个都注册了、只是排序碰巧空态在前」。
        #expect(harness.standardItemIsActive == false)

        // 全新安装无任何对话 → 不应注册 chats tab。
        #expect(
            !harness.rail.tabs.contains { $0.id == "\(harness.conversationListID).chats" },
            "全新安装时不应注册对话列表 tab —— 用户会看到一条空侧栏"
        )
    }

    /// 首条消息发出后：槽位从空态交还给消息列表。
    @Test("首条消息写入后空态交还 message-list 槽位")
    func firstMessageHandsSlotBackToMessageList() async throws {
        let harness = try await FreshInstallHarness.make()
        #expect(harness.renderedMessageListItemID == harness.emptyPluginID)

        // 模拟一次真实发送：创建会话（内部自动选中）并写入首条用户消息。
        try await harness.sendFirstMessage(text: "Fresh Install First Message Probe")

        let handedBack = await harness.waitUntil {
            harness.renderedMessageListItemID == harness.standardPluginID
        }
        #expect(
            handedBack,
            """
            写入首条消息后槽位未交还消息列表。实际渲染 \
            \(harness.renderedMessageListItemID ?? "nil")；\
            空态插件的 isActive 判定（.evaluating / .resolved(true)）没有随消息插入收敛。
            """
        )
    }

    /// 首条消息发出后：`chats` Rail tab 注册，且宿主 Rail 可见性同步为 true。
    ///
    /// 这是用户描述的「输入消息后 railview 展示出对话列表」的直接对应物。
    @Test("首条消息创建会话后注册 chats tab 并同步 Rail 可见性")
    func firstMessageRegistersChatsTabAndShowsRail() async throws {
        let harness = try await FreshInstallHarness.make()
        let chatsTabID = "\(harness.conversationListID).chats"

        // 前置：无 tab，但 Rail 栏本身**已经可见**。
        //
        // - Important: 这里断言 `true` 而不是 `false`，是刻意的。全新安装时
        //   `ChatPanelPlugin.onBoot` 末尾无条件 `setRailViewVisible(true)`，
        //   而 `ConversationRailTabController` 会按 `hasVisibleTabs == false`
        //   写回 `false`；最终可见性由 ChatPanel 的 `rootViewObserver`
        //   监听 `.railViewVisibilityChanged(false)` 后顶回 `true` 决定。
        //   即产品语义是「首屏 Rail 栏在、内部为空」，随首条消息出现的是
        //   **tab** 而非整条栏。把这里写成 false 会把真实设计固化成 bug。
        #expect(harness.rail.tabs.isEmpty)
        #expect(
            harness.rootView.isRailViewVisible,
            "Chat 激活时 Rail 栏应保持可见（内容区为空），这条由 ChatPanel 的观察者顶回"
        )

        try await harness.sendFirstMessage(text: "Rail Reveal Probe")

        let tabRegistered = await harness.waitUntil {
            harness.rail.tabs.contains { $0.id == chatsTabID }
        }
        #expect(
            tabRegistered,
            "创建首个会话后未注册 chats Rail tab —— 用户输入消息后看不到对话列表"
        )

        let railVisible = await harness.waitUntil { harness.rootView.isRailViewVisible }
        #expect(
            railVisible,
            "注册可见 tab 后宿主 Rail 仍不可见 —— 对话列表注册成功但用户看不到侧栏"
        )
        // Rail 视图必须已注入，而不只是可见（WorkbenchSplitView 两者都要）。
        #expect(harness.rootView.view(for: .rail) != nil)
    }

    /// 空态与对话列表互相独立：清空消息应把槽位还给空态，**但不**注销已注册 tab。
    ///
    /// 两者的触发源不同（消息变更 vs 会话增删），耦合在一起会让一侧的回归
    /// 伪装成另一侧的缺陷。
    @Test("清空消息只交还槽位而不注销 chats tab")
    func clearingMessagesDoesNotUnregisterChatsTab() async throws {
        let harness = try await FreshInstallHarness.make()
        try await harness.sendFirstMessage(text: "Clear Probe")

        let chatsTabID = "\(harness.conversationListID).chats"
        _ = await harness.waitUntil { harness.rail.tabs.contains { $0.id == chatsTabID } }
        #expect(harness.rail.tabs.contains { $0.id == chatsTabID })

        harness.messages.clearMessages(in: harness.conversationID)

        // `clearMessages` 先同步排空写队列再删库，随后空态插件异步重判。
        // 这里等「数据库里真的没有消息了」，而不是等槽位变化 ——
        // 槽位在判定在途期间会让位给消息列表，过早断言会读到中间态。
        let actuallyEmpty = await harness.waitUntilAsync {
            await harness.messages.messagePageAsync(
                for: harness.conversationID,
                limit: 1,
                beforeMessageID: nil,
                includesToolMessages: false
            ).isEmpty
        }
        #expect(actuallyEmpty, "清空消息后数据库中仍有可见消息 —— 前置操作未生效")

        let slotBack = await harness.waitUntil {
            harness.renderedMessageListItemID == harness.emptyPluginID
        }
        #expect(slotBack, "清空消息后槽位未交还空态")
        #expect(
            harness.rail.tabs.contains { $0.id == chatsTabID },
            "会话仍存在，chats tab 不该被注销 —— 这是对话列表侧的缺陷，与空态无关"
        )
    }
}

// MARK: - Harness

/// 用**真实**插件 + 真实 Provider 跑一遍全新安装的装配。
///
/// 只重定向数据根目录到临时目录，不 mock 任何 Provider：接缝失效往往来自
/// 真实的订阅时序与 SwiftData 可见性，替身会把它们掩盖掉。
@MainActor
private final class FreshInstallHarness {
    let kernel: KernelCoreContainer
    let chat: DefaultChatSectionProviding
    let messages: MessageManager
    let rail: DefaultRailViewProviding
    let rootView: DefaultRootViewProviding
    let activityBar: DefaultActivityBarProviding
    let conversations: DefaultConversationManager

    let emptyPluginID = "com.coffic.lumi.plugin.message-list.empty"
    let standardPluginID = "com.coffic.lumi.plugin.message-list.standard"
    let conversationListID = "com.coffic.lumi.plugin.conversation-list"

    /// 必须强持有插件：空态 item 的 `isActive` 闭包以 `[weak self]` 捕获插件，
    /// 插件被释放后闭包恒返回 false，会让「空态从不渲染」假象通过断言。
    private let emptyPlugin: PluginMessageListEmptyPlugin
    private let standardPlugin: PluginMessageListStandardPlugin
    private let conversationListPlugin: ConversationListPlugin
    private let chatPanelPlugin: ChatPanelPlugin
    private let storageRoot: URL

    /// 当前会话 id，发送后更新。
    var conversationID: UUID { _conversationID }
    private var _conversationID: UUID = UUID()

    /// 同一 `exclusiveGroup` 下最终会渲染的 item id。
    ///
    /// ## 为什么不能简化成「第一个 isActive 的 item」
    ///
    /// 真实仲裁在 `DefaultChatSectionProviding.exclusiveItems` 里分两步：
    /// 先按 `isActive()` 过滤，**再**对每组只保留排序后的首个。也就是说
    /// 「过滤后取首个」与「取首个再判断」不等价 —— 空态 `order = 81` 排在
    /// 标准 `order = 82` 之前，标准即使 active 也会被空态压掉（若空态也 active）。
    /// 这里逐步复刻该顺序，避免测试用比产品更宽松的规则而漏报。
    var renderedMessageListItemID: String? {
        var seenGroups = Set<String>()
        return chat.items
            .filter { $0.placement == .stack }
            .filter { $0.scope.matches(chat.activeContext) }
            .filter { $0.isActive() }
            .filter { item in
                guard let group = item.exclusiveGroup else { return true }
                return seenGroups.insert(group).inserted
            }
            .first?
            .id
    }

    /// 标准消息列表此刻是否认为自己可见（排除「空态靠排序压住它」）。
    var standardItemIsActive: Bool {
        chat.items.first { $0.id == standardPluginID }?.isActive() ?? false
    }

    private init(
        kernel: KernelCoreContainer,
        chat: DefaultChatSectionProviding,
        messages: MessageManager,
        rail: DefaultRailViewProviding,
        rootView: DefaultRootViewProviding,
        activityBar: DefaultActivityBarProviding,
        conversations: DefaultConversationManager,
        emptyPlugin: PluginMessageListEmptyPlugin,
        standardPlugin: PluginMessageListStandardPlugin,
        conversationListPlugin: ConversationListPlugin,
        chatPanelPlugin: ChatPanelPlugin,
        storageRoot: URL
    ) {
        self.kernel = kernel
        self.chat = chat
        self.messages = messages
        self.rail = rail
        self.rootView = rootView
        self.activityBar = activityBar
        self.conversations = conversations
        self.emptyPlugin = emptyPlugin
        self.standardPlugin = standardPlugin
        self.conversationListPlugin = conversationListPlugin
        self.chatPanelPlugin = chatPanelPlugin
        self.storageRoot = storageRoot
    }

    static func make() async throws -> FreshInstallHarness {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreshInstall-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let kernel = KernelCoreContainer()

        let storage = DefaultStorageProvider(dataRootDirectory: root)
        try kernel.registerProvider((any StorageProviding).self, storage)

        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)

        let rail = DefaultRailViewProviding()
        try kernel.registerProvider((any RailViewProviding).self, rail)

        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        let activityBar = DefaultActivityBarProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)

        let project = DefaultProjectProvider()
        try kernel.registerProvider((any ProjectProviding).self, project)

        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let tools = DefaultToolManagerProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, tools)

        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)

        // 真实 SwiftData 消息存储（write-behind），确保走数据库读取路径。
        //
        // 用 `MessageManager` 而非内存版 `DefaultMessageManager`：空态插件判定
        // 「有无消息」走的是 `messagePageAsync` 的数据库路径，内存替身会让
        // write-behind 的可见性窗口消失，掩盖真实的判定竞态。
        let store = try MessageStore(
            databaseRootURL: root.appendingPathComponent("message-store", isDirectory: true)
        )
        let messages = MessageManager(store: store, dataDirectory: root)
        try kernel.registerProvider((any MessageManaging).self, messages)

        // 四个真实插件按真实顺序装配：ChatPanel 先于 ConversationList，
        // 与 FactoryLumi 的插件顺序一致（ChatPanel order = 1）。
        let chatPanel = ChatPanelPlugin()
        try chatPanel.onBoot(kernel: kernel)

        let conversationList = ConversationListPlugin()
        try conversationList.onBoot(kernel: kernel)

        let standard = PluginMessageListStandardPlugin()
        try standard.onBoot(kernel: kernel)

        let empty = PluginMessageListEmptyPlugin()
        try empty.onBoot(kernel: kernel)

        let harness = FreshInstallHarness(
            kernel: kernel,
            chat: chat,
            messages: messages,
            rail: rail,
            rootView: rootView,
            activityBar: activityBar,
            conversations: conversations,
            emptyPlugin: empty,
            standardPlugin: standard,
            conversationListPlugin: conversationList,
            chatPanelPlugin: chatPanel,
            storageRoot: root
        )

        // 等空态插件的首次异步判定落地（它读的是真实 SwiftData）。
        // 在实例上调用：`settleUntilSettled` 依赖实例状态，故不能走 `Self.`。
        await harness.settleUntilSettled()
        return harness
    }

    /// 模拟一次真实发送：`createConversation` + 写入首条 user 消息。
    ///
    /// `createConversation` 内部会自动 `cache` 并把该会话设为选中态
    /// （见 `DefaultConversationManager.createConversation`），这正是
    /// 空态插件观察者链与对话列表 `.created` 事件的真实触发点。
    func sendFirstMessage(text: String) async throws {
        let id = try conversations.createConversation(
            title: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        _conversationID = id
        messages.insertMessage(
            Message(conversationID: id, role: .user, content: text),
            to: id
        )
        await settleUntilSettled()
    }

    /// 给真实挂钟时间跑完异步判定。
    ///
    /// - Important: 这里**必须等条件，不能等时长**。空态插件的判定链是
    ///   `消息观察者 → scheduleRegistrationEvaluation → Task → SwiftData 异步读`，
    ///   对话列表另有 80ms 去抖。固定 sleep 在单独跑时够用、在整包并发时
    ///   不够（表现为 `清空消息` 用例偶发失败），且失败点会随机器负载漂移，
    ///   极易被误判成产品缺陷。因此统一改用「等目标状态真的出现」。
    private func settleUntilSettled() async {
        // 空态插件的判定无对外完成信号，只能等它不再处于「判定中」：
        // `.evaluating` 时 `isActive` 恒为 false，槽位会被上一位渲染者占住。
        _ = await waitUntil { !emptyPluginIsEvaluating }
        // 再给去抖窗口一点余量：对话列表的 80ms debounce 尚未启动时
        // 上面的条件可能已满足，但 rail 的写入还没发生。
        try? await Task.sleep(for: .milliseconds(120))
    }

    /// 空态插件当前是否处于「判定中」。
    ///
    /// 用渲染结果反推而非读取内部状态：判定在途时空态让位给消息列表，
    /// 因此「空态重新占据槽位」等价于判定已收敛为 `.resolved(true)`。
    /// 这条性质本身也是被测对象之一，不宜作为前提依赖。
    private var emptyPluginIsEvaluating: Bool {
        !chat.items
            .filter { $0.placement == .stack }
            .contains { $0.id == emptyPluginID && $0.isActive() }
    }

    func waitUntil(timeout: Duration = .seconds(5), condition: @MainActor () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// 等待一个**需要 await 才能求值**的条件成立。
    ///
    /// 数据库可见性断言（`messagePageAsync`）只能走这条路径：把 await 塞进
    /// 同步闭包里会让条件变成「尚未开始求值的 Task」，恒为假 —— 那正是此前
    /// 「清空消息」用例在整包并发下偶发失败的根因。
    func waitUntilAsync(
        timeout: Duration = .seconds(5),
        condition: @MainActor () async -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await condition()
    }

    func tearDown() {
        try? conversationListPlugin.onShutdown(kernel: kernel)
        try? chatPanelPlugin.onShutdown(kernel: kernel)
        try? emptyPlugin.onShutdown(kernel: kernel)
        try? standardPlugin.onShutdown(kernel: kernel)
        try? FileManager.default.removeItem(at: storageRoot)
    }
}
