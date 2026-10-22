import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListBrief

/// 大数据量场景下的消息列表行为测试（V1 / brief 模式）。
///
/// 这组用例针对 V1 消息列表在**长会话 / 高消息量**下的表现，与 V2（standard）
/// / V3（detailed）的同名用例一一对应：三个插件互不依赖、各自一份实现，
/// 缺陷必须同步修复，改一处须同步另两处。
///
/// V1 的特殊性：brief 视图的每一行是由窗口里的消息按 `turnID` 聚合出来的。
/// 因此窗口回收必须**整段裁 turn**（裁半个 turn 会让那一行显示成残缺内容），
/// 且**最新 turn 受保护**（它是用户当前所在的对话，裁掉会让整行消失）。
@MainActor
@Suite("V1 大数据量行为")
struct ListV1LargeDataTests {

    // MARK: - 测试替身

    /// 具备真实游标分页语义的能力替身。
    final class StubMessages: MessageListMessageCapability {
        /// 全量消息（按时间升序）。
        var all: [Message] = []

        init(all: [Message]) { self.all = all }

        func messagesSnapshot(in conversationID: UUID) async -> [Message] { all }

        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> [Message] {
            let filtered = all.filter { includesToolMessages || $0.role != .tool }
            guard let beforeMessageID else { return Array(filtered.suffix(limit)) }
            guard let index = filtered.firstIndex(where: { $0.id == beforeMessageID }) else { return [] }
            return Array(filtered[max(0, index - limit)..<index])
        }

        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> Bool {
            let filtered = all.filter { includesToolMessages || $0.role != .tool }
            guard let beforeMessageID else { return filtered.count > 10 }
            guard let index = filtered.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
            return index > 0
        }
    }

    /// 提供一个稳定 `selectedConversationID`。
    final class StubConversations: MessageListConversationCapability {
        var selected: UUID?
        var verbosityToReturn: ResponseVerbosity = .brief
        init(selected: UUID? = nil) { self.selected = selected }
        var selectedConversationID: UUID? { selected }
        func verbosity(for conversationID: UUID?) -> ResponseVerbosity { verbosityToReturn }
    }

    private func makeServices(
        messages: any MessageListMessageCapability,
        conversations: any MessageListConversationCapability
    ) -> MessageListServices {
        MessageListServices(
            conversations: conversations,
            developerMode: nil,
            messages: messages,
            rendering: nil,
            agentTurn: nil
        )
    }

    /// 读取 VM 的私有消息窗口。
    ///
    /// 用 Mirror 反射而不是在生产代码里开观察缝：窗口规模是内存不变式，
    /// 不该为了测试改动生产 API。
    private func windowMessages(of vm: ConversationMessageListVM) -> [Message] {
        for child in Mirror(reflecting: vm).children {
            if child.label == "messageWindow", let messages = child.value as? [Message] {
                return messages
            }
        }
        return []
    }

    /// 构造一条按时间递增的消息（每条一个 turn）。
    private func message(
        _ index: Int,
        conversationID: UUID,
        turnID: UUID,
        base: TimeInterval = 1_700_000_000
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "m\(index)",
            createdAt: Date(timeIntervalSince1970: base + Double(index)),
            turnID: turnID
        )
    }

    // MARK: - 有界性：内存窗口必须有上限

    /// 无论用户怎么翻页，内存窗口都不能无上限增长。
    ///
    /// ## 缺陷背景
    ///
    /// `ConversationMessageListVM.loadEarlier` 把更早一页直接前插进消息窗口，
    /// 全程没有任何回收：用户在底部反复触发「加载更早消息」时，窗口会一路涨到
    /// 整个会话的消息数。
    ///
    /// 实测 2000 条消息全量进入内存：每条都带完整正文与渲染元数据，
    /// 展示行同步重建，ForEach 的 diff 集合也随之膨胀。
    @Test("持续翻页时内存窗口不得无上限增长")
    func windowStaysBoundedWhilePaging() async {
        let conversationID = UUID()
        let all = (0..<2000).map { index in
            message(index, conversationID: conversationID, turnID: UUID())
        }
        let services = makeServices(
            messages: StubMessages(all: all),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)

        // 连续翻页 50 次（每页 40 条 → 理论可涨到 2000）。
        for _ in 0..<50 {
            _ = await vm.loadEarlier()
        }

        let window = windowMessages(of: vm)
        #expect(
            window.count <= 300,
            "连续翻页后窗口涨到 \(window.count) 条，窗口上限失效"
        )
    }

    // MARK: - 正确性：回收不得损坏展示行

    /// 窗口回收不得裁掉最新 turn 的消息。
    ///
    /// brief 视图的每一行由窗口里的消息按 `turnID` 聚合而成。最新 turn 是用户
    /// 当前所在的对话（可能正在流式），把它裁掉会让**当前对话整行**从列表消失。
    @Test("窗口回收不得裁掉最新 turn 的消息")
    func evictionKeepsNewestTurnMessages() async {
        let conversationID = UUID()
        let newestTurnID = UUID()
        var all = (0..<300).map { index in
            message(index, conversationID: conversationID, turnID: UUID())
        }
        // 最新 turn 有 3 条消息。
        let newestTurnMessages = (0..<3).map { offset in
            message(1000 + offset, conversationID: conversationID, turnID: newestTurnID)
        }
        all.append(contentsOf: newestTurnMessages)

        let services = makeServices(
            messages: StubMessages(all: all),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)

        for _ in 0..<10 {
            _ = await vm.loadEarlier()
        }

        let window = windowMessages(of: vm)
        let windowIDs = Set(window.map(\.id))
        let newestIDs = Set(newestTurnMessages.map(\.id))
        #expect(
            newestIDs.isSubset(of: windowIDs),
            "最新 turn 的消息被窗口回收裁掉了：\(newestIDs.subtracting(windowIDs))"
        )
        #expect(
            vm.agentTurns.contains { $0.id == newestTurnID },
            "最新 turn 整行从列表里消失了"
        )
    }

    /// 向上翻页触发窗口回收后，刷新必须把被裁掉的空档接回来。
    ///
    /// ## 缺陷背景
    ///
    /// 回收裁掉的是窗口尾部较新的一段。那一段既不在窗口里、也不在「更早」方向上
    /// —— 它落在**窗口尾部之后**，只有一次尾部刷新能把它带回来。
    ///
    /// 若刷新只拼接「最近一页」，窗口尾部与最近一页之间的**空档**就会被永久留下：
    /// 那一段既翻不到（翻页只会更早）、也看不到（不在窗口里）—— 数据丢失级缺陷。
    @Test("翻页裁剪窗口后，刷新必须把中间段消息接回来")
    func refreshBackfillsTheEvictedGap() async {
        let conversationID = UUID()
        var all = (0..<400).map { index in
            message(index, conversationID: conversationID, turnID: UUID())
        }
        let services = makeServices(
            messages: StubMessages(all: all),
            conversations: StubConversations(selected: conversationID)
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activate(conversationID: conversationID)

        for _ in 0..<10 {
            _ = await vm.loadEarlier()
        }

        _ = await vm.refresh()

        let contents = Set(windowMessages(of: vm).map(\.content))
        let missing = (0..<400).map { "m\($0)" }.filter { !contents.contains($0) }
        #expect(
            missing.isEmpty,
            "以下消息从窗口中永久消失（既翻不到也不显示）：\(missing.prefix(10))…共 \(missing.count) 条"
        )
    }
}
