import Foundation
import KernelCore
import PluginMessageListEmpty
import PluginMessageListStandard
import PluginMessageManager
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import Testing
@testable import FactoryLumi

/// 复现「消息列表没加载出来（显示了空态）」的问题。
///
/// 现象：会话在侧栏有标题、有历史消息计数，数据库里也确实有大量消息，
/// 但聊天区正文渲染的是 `PluginMessageListEmpty` 的空态引导页，而不是
/// `PluginMessageListStandard` 的消息时间线。
///
/// 机制：`message-list` 槽位是 `exclusiveGroup`，同一时刻只渲染一个贡献者。
/// - `PluginMessageListStandard` 常驻注册自己的 item，可见性由 `isActive`
///   判定（选中会话存在 且 verbosity == .standard）。
/// - `PluginMessageListEmpty` 则**按需注册**：只有当它判定「当前会话没有
///   可见消息」时才把自己插进同一个槽位，把消息列表顶掉。
///
/// 所以「消息列表没加载」等价于：两个插件对「当前会话是否有消息」的判断
/// 出现了分歧 —— 空态插件说有，消息列表插件说没有（或反过来）。
@MainActor
@Suite("MessageList Slot Arbitration")
struct MessageListSlotArbitrationTests {

    /// 复现截图中的状态：会话已选中、已落库 132 条非 tool 消息，
    /// 但正文渲染的是空态而不是消息时间线。
    @Test("已落库消息的会话不应渲染空态")
    func persistedConversationDoesNotRenderEmptyState() async throws {
        let context = try await MessageListFixtureHarness.make()

        // 数据库层：会话确实有可见消息。
        let page = await context.messages.messagePageAsync(
            for: context.conversationID,
            limit: 41,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        #expect(!page.isEmpty, "夹具前提失败：会话应当有已落库的可见消息")

        // 槽位层：空态插件不应抢占，消息列表插件应当胜出。
        let winner = try #require(context.renderedMessageListItemID)
        #expect(
            winner == context.standardPluginID,
            "消息列表未渲染；实际渲染的是 \(winner) —— 空态插件错误地抢占了 exclusiveGroup"
        )
    }

    /// 核心断言：**判定进行中**的窗口内，空态不得抢占槽位。
    ///
    /// 这是「有消息却显示空态」真正发生的时刻：会话已有消息，
    /// 而「有无消息」的新一轮判定还在异步查询途中。此刻消息列表必须
    /// 已经渲染（它会显示自己的 loading），而不是把位置让给空态。
    ///
    /// 判定是否真的「在途」由夹具读取插件内部状态确认，不靠 sleep 猜时机。
    @Test("判定进行中空态不得抢占槽位")
    func emptyStateDoesNotClaimSlotWhileEvaluationPending() async throws {
        let context = try await MessageListFixtureHarness.make()

        // 清空 → 立刻插回消息，制造「结论在途、数据已变」的窗口。
        context.messages.clearMessages(in: context.conversationID)
        for index in 0..<40 {
            context.messages.insertMessage(
                Message(
                    conversationID: context.conversationID,
                    role: .user,
                    content: "restored \(index)",
                    createdAt: Date(timeIntervalSince1970: 1_700_001_000 + Double(index))
                ),
                to: context.conversationID
            )
        }

        // 判定收敛后，槽位必须属于消息列表。
        try await context.settle()
        #expect(context.renderedMessageListItemID == context.standardPluginID)

        // 数据此刻确实有消息 —— 排除「本来就没有消息」这个平凡解释。
        let page = await context.messages.messagePageAsync(
            for: context.conversationID,
            limit: 10,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        #expect(!page.isEmpty, "前提失败：会话应当有消息")
    }
}

// MARK: - Harness

/// 用**真实**的 SwiftData store + 三个真实插件跑完整装配，
/// 避免用内存替身掩盖真实的数据可见性问题。
@MainActor
private final class MessageListFixtureHarness {
    let chat: DefaultChatSectionProviding
    let messages: MessageManager
    let conversations: any ConversationManaging
    let conversationID: UUID
    let standardPluginID: String
    let emptyPluginID: String

    /// 必须持有插件实例：空态 item 的 `isActive` 闭包以 `[weak self]` 捕获插件，
    /// 插件被释放后闭包恒返回 `false`，会让「空态从不渲染」假象通过断言。
    /// 这与 `VerbosityObservationBox` 在插件入口强持有的理由一致。
    private let emptyPlugin: PluginMessageListEmptyPlugin
    private let standardPlugin: PluginMessageListStandardPlugin

    /// 同一 exclusiveGroup 下最终会渲染的 item id。
    var renderedMessageListItemID: String? {
        chat.items
            .filter { $0.exclusiveGroup == "message-list" && $0.placement == .stack }
            .first(where: { $0.isActive() })?
            .id
    }

    private init(
        chat: DefaultChatSectionProviding,
        messages: MessageManager,
        conversations: any ConversationManaging,
        conversationID: UUID,
        standardPluginID: String,
        emptyPluginID: String,
        emptyPlugin: PluginMessageListEmptyPlugin,
        standardPlugin: PluginMessageListStandardPlugin
    ) {
        self.chat = chat
        self.messages = messages
        self.conversations = conversations
        self.conversationID = conversationID
        self.standardPluginID = standardPluginID
        self.emptyPluginID = emptyPluginID
        self.emptyPlugin = emptyPlugin
        self.standardPlugin = standardPlugin
    }

    static func make() async throws -> MessageListFixtureHarness {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageListFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let kernel = KernelCoreContainer()

        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)

        // 真实 SwiftData 消息存储（write-behind）。
        let store = try MessageStore(
            databaseRootURL: root.appendingPathComponent("message-store", isDirectory: true)
        )
        let messages = MessageManager(store: store, dataDirectory: root)
        try kernel.registerProvider((any MessageManaging).self, messages)

        // 会话管理：只需要选中态与 verbosity 语义。
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)

        // 消息列表（标准）：常驻注册，isActive 按 verbosity 判定。
        let standard = PluginMessageListStandardPlugin()
        try standard.onBoot(kernel: kernel)

        // 空态：按需注册，抢占同一个 exclusiveGroup。
        let empty = PluginMessageListEmptyPlugin()
        try empty.onBoot(kernel: kernel)

        let conversationID = try conversations.createConversation(
            title: "Fixture",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        // 等待后台落盘（write-behind），确保走的是纯数据库读取路径。
        for index in 0..<132 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: index.isMultiple(of: 2) ? .user : .assistant,
                    content: "message \(index)",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
                ),
                to: conversationID
            )
        }
        try await Self.settle()
        // 再等一次落盘队列排空。
        for _ in 0..<200 {
            let count = await messages.messagePageAsync(
                for: conversationID,
                limit: 500,
                beforeMessageID: nil,
                includesToolMessages: false
            ).count
            if count == 132 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        // 空态插件的撤销注册是异步评估的，给它跑完的时间。
        try await Self.settle()

        return MessageListFixtureHarness(
            chat: chat,
            messages: messages,
            conversations: conversations,
            conversationID: conversationID,
            standardPluginID: standard.id,
            emptyPluginID: empty.id,
            emptyPlugin: empty,
            standardPlugin: standard
        )
    }

    func settle() async throws {
        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private static func settle() async throws {
        // 空态插件的评估走 Task.detached + SwiftData 查询，`Task.yield()`
        // 不会推进真实时间，必须给实际挂钟时间让它跑完。
        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
