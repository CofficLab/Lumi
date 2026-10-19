import XCTest

/// 「全新安装 → 首屏空态 → 发出首条消息 → 看到对话列表」这条旅程的 UI 测试。
///
/// ## 为什么单元测试钉不住这条链路
///
/// `FactoryLumiTests` 的 `FreshInstallFirstMessageAssemblyTests` 已经用真实
/// 插件 + 真实 Provider 覆盖了同一旅程的**装配层**不变量（空态占槽、首条消息
/// 后交还槽位、chats tab 注册、Rail 可见性写回）。但那层有两个盲区：
///
/// 1. **不经过真实启动流程**。它直接调 `onBoot(kernel:)`，绕过了插件
///    `policy` 解析、`PluginManager` 启用集合、`onReady` 时序与宿主
///    `ViewFactory` 的绑定。新增一个 `alwaysOn` 插件、或启用态持久化被误当作
///    默认启用，都能让新用户看到完全不同的首屏，而这层测试不会察觉。
/// 2. **不经过真实渲染**。它断言的是 `ChatSectionItem.isActive` 这类闭包返回值，
///    而 SwiftUI 是否真的把对应 View 挂上屏、AX 树里是否真的出现该标识符，
///    只有驱动真实 App 才能确认。
///
/// 两者叠加的典型回归：`PluginMessageListEmpty` 的 `isActive` 判定正确、
/// `ChatSection` 仲裁也正确，但因为插件压根没 boot，聊天区就是空的 ——
/// 装配层测试全绿，用户看到空白。
///
/// ## 确定性来源
///
/// `--lumi-ui-testing-isolated-storage` 把数据根目录重定向到临时目录下的
/// 全新 UUID 子目录（见 `KernelFactory.uiTestingDataRootDirectory()`），
/// 效果等价于全新安装：无任何对话、无已启用插件记录、无保存的 Rail 激活项。
final class LumiFreshInstallEmptyStateUITests: LumiUITestCase {

    /// 空态的可访问性标识符（复述 `MessageListEmptyAccessibility`）。
    ///
    /// 改动必须与 `Packages/PluginMessageListEmpty/.../MessageListEmptyAccessibility.swift`
    /// 同步，否则本文件会在「元素找不到」上失败。
    private enum EmptyState {
        static let noConversationSelectedID = "lumi.message-list.empty.no-conversation-selected"
        static let noMessagesID = "lumi.message-list.empty.no-messages"
        static let defaultTitle = "How can I help you today?"
    }

    /// 对话列表的可访问性标识符（复述 `ConversationListAccessibility`）。
    private enum ConversationList {
        static let listID = "lumi.conversation-list"
        static let itemID = "lumi.conversation-list.item"
    }

    /// 聊天输入栏标识符（复述 `LumiUITestCase.SendActionBar` 与既有 UI 测试）。
    private enum Input {
        static let editor = "lumi.conversation-input.editor"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 确定性 LLM 供应商（UI 测试桩）。缺了它，新装环境里没有任何可用
            // 供应商，发出的消息无法真正跑完回合，后续「消息上屏」断言会因
            // 前置失败而失去意义。与 SendActionBar / AskUser 等用例保持一致。
            "--lumi-ui-testing",
            "--lumi-ui-testing-isolated-storage",
        ])
        // 基类在等主窗口就绪后会关掉新手引导（隔离存储会让引导重新出现，
        // 它是覆盖在聊天区之上的浮层，不关掉就点不到输入框）。
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Cases

    /// 全新安装首屏：展示「未选中对话」的空态，而非空白。
    ///
    /// 这是整条旅程的起点判据。若此用例失败，后续「发消息后出现对话列表」
    /// 的断言全部失去意义 —— 用户可能根本没走到那一步。
    func testFreshInstallShowsEmptyStateInsteadOfBlankChat() throws {
        let emptyState = element(identifier: EmptyState.noConversationSelectedID)

        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 20),
            """
            全新安装首屏未出现空态引导页（标识符 \(EmptyState.noConversationSelectedID)）。\
            可能原因：空态插件未 boot（检查 policy / 启用态）、\
            ChatSection 的 message-list 槽位无人占据（检查 PluginMessageListEmpty 注册），\
            或该标识符已从 NoConversationSelectedView 移除。
            """
        )

        // 主窗口仍在 —— 排除「App 崩溃导致元素不存在」的假阴性。
        XCTAssertTrue(
            element(identifier: "root.main").exists,
            "主窗口消失，App 可能已崩溃，空态断言失去意义"
        )

        // 输入框同时在场：空态不应阻断发送。
        XCTAssertTrue(
            element(identifier: Input.editor).waitForExistence(timeout: 10),
            "空态状态下聊天输入框不存在，用户无法发起首次对话"
        )
    }

    /// 首条消息发出后：对话列表出现在左侧 Rail 中。
    ///
    /// 这条用例覆盖用户描述的核心变化 —— 输入消息产生新对话后，能看到对话列表。
    func testFirstMessageMakesConversationListAppear() throws {
        // 前置：全新安装时左侧没有会话列表（否则「出现」无从谈起）。
        XCTAssertFalse(
            element(identifier: ConversationList.itemID).exists,
            "全新安装时就已存在会话行，前置不成立；本用例无法证明「首条消息使其出现」"
        )

        let probe = "Fresh Install Conversation List Probe"
        XCTAssertTrue(
            typeAndSend(probe, editorIdentifier: Input.editor),
            "发送首条消息失败，无法继续验证对话列表"
        )

        // 会话行出现。这是「首条消息 → 对话列表可见」的直接证据。
        let conversationRow = element(identifier: ConversationList.itemID)
        XCTAssertTrue(
            conversationRow.waitForExistence(timeout: 30),
            """
            发出首条消息后对话列表仍未出现（标识符 \(ConversationList.itemID)）。\
            可能原因：createConversation 的 .created 事件未触发 \
            ConversationRailTabController 的去抖刷新，或 chats tab 未注册，\
            或宿主 Rail 可见性未被写回为 true。
            """
        )

        // 会话内容确实落在首屏：证明不是空壳列表。
        XCTAssertTrue(
            element(containingLabel: probe).waitForExistence(timeout: 20),
            "对话列表出现了，但首条消息未显示在聊天区 —— 用户会以为消息丢失"
        )
    }

    /// 首条消息后：空态让位给消息列表。
    ///
    /// 空态与消息列表竞争同一个 `exclusiveGroup` 槽位，因此「空态还在」与
    /// 「消息能看见」互斥。把这一条单独断言，是为了让失败时的报错直接指向
    /// 仲裁环节，而不是让上层用例报「元素找不到」。
    ///
    /// - Important: 不要断言「`no-messages` 空态曾出现」这类中间态。用户消息
    ///   在发送管线里**先落库再渲染**，第一次渲染时会话已经有消息了，那个
    ///   「选中了会话但没有消息」的帧根本不会画出来。此前按中间态写，超时后
    ///   报成「既未出现空态也未出现消息列表」，把「发送链路正常」误报成缺陷。
    ///   可观察的判据只有两个：**空态最终都消失**、**消息列表接管了聊天区**。
    func testEmptyStateIsReplacedByMessageListAfterFirstMessage() throws {
        let noMessages = element(identifier: EmptyState.noMessagesID)
        let noConversation = element(identifier: EmptyState.noConversationSelectedID)

        XCTAssertTrue(
            typeAndSend("Handover Probe", editorIdentifier: Input.editor),
            "发送首条消息失败"
        )

        // 两种空态最终都必须消失。
        let gone = waitForNonExistence(noConversation, timeout: 30)
            && waitForNonExistence(noMessages, timeout: 5)
        XCTAssertTrue(
            gone,
            """
            已有消息后空态仍未让位（\(EmptyState.noConversationSelectedID) / \(EmptyState.noMessagesID)）。\
            空态 order=81 早于标准列表 order=82，仲裁只看 order —— \
            一旦空态的 isActive 误判为 true 就会永久压住消息列表。
            """
        )

        // 空态消失不等于有内容：消息正文必须真的渲染出来。
        XCTAssertTrue(
            element(containingLabel: "Handover Probe").waitForExistence(timeout: 20),
            "空态让位了，但首条消息未显示在聊天区 —— 用户会以为消息丢失"
        )
    }
}
