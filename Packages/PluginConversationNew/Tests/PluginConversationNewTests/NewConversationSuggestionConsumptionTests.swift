import Foundation
import Testing
import ProviderConversation
import ProviderMessage
@testable import PluginConversationNew

/// 建议卡片「已打开」状态的幂等回归（**#632**、**#592**）。
///
/// 修复前消费状态只存在 `@State private var phase`：切换会话导致卡片重建（#632）
/// 或应用重启（#592）后 phase 回到 idle，再点一次会重复发送首条消息并重复启动
/// 回合。修复后以消息存储（首条用户消息是否已存在）为准：出现时校正为「已打开」，
/// 点击已消费目标只导航、不再发送。
@Suite("建议卡片消费幂等（#632、#592）")
@MainActor
struct NewConversationSuggestionConsumptionTests {
    private func makeSuggestion(_ id: UUID) -> NewConversationSuggestion {
        NewConversationSuggestion(conversationID: id, title: "B", starter: "Do an unrelated task here")
    }

    private func makeCapability(
        sourceID: UUID,
        targetID: UUID,
        consumed: Bool
    ) -> MockNewChatCapability {
        let capability = MockNewChatCapability()
        capability.existingConversationIDs = [sourceID, targetID]
        if consumed { capability.consumedStarterIDs = [targetID] }
        capability.restoreSelection(to: sourceID)
        return capability
    }

    // MARK: - 点击路径

    @Test("首条消息已发出时只导航到既有对话，不重复发送（**回归 #632/#592**）")
    func consumedTargetNavigatesWithoutResending() async throws {
        let sourceID = UUID()
        let targetID = UUID()
        let capability = makeCapability(sourceID: sourceID, targetID: targetID, consumed: true)
        let sender = ConsumptionStubStarting()

        let opened = await NewConversationSuggestionCard.performStart(
            suggestion: makeSuggestion(targetID),
            conversations: capability,
            sender: sender
        )

        #expect(opened == true, "已消费目标仍应视为成功打开")
        #expect(sender.calls.isEmpty, "不得重复发送首条消息、不得启动第二个回合")
        #expect(capability.selections == [targetID], "应导航到既有对话")
        #expect(capability.selectedConversationID == targetID)
    }

    @Test("首条消息未发出时正常发送一次")
    func unconsumedTargetSendsOnce() async throws {
        let sourceID = UUID()
        let targetID = UUID()
        let capability = makeCapability(sourceID: sourceID, targetID: targetID, consumed: false)
        let sender = ConsumptionStubStarting()

        let opened = await NewConversationSuggestionCard.performStart(
            suggestion: makeSuggestion(targetID),
            conversations: capability,
            sender: sender
        )

        #expect(opened == true)
        #expect(sender.calls == [targetID])
        #expect(capability.selectedConversationID == targetID)
    }

    @Test("卡片重建后再次点击不产生第二条首条消息（**回归 #632**）")
    func secondStartAfterConsumptionDoesNotDuplicateSend() async throws {
        let sourceID = UUID()
        let targetID = UUID()
        let capability = makeCapability(sourceID: sourceID, targetID: targetID, consumed: false)
        let sender = ConsumptionStubStarting()
        let suggestion = makeSuggestion(targetID)

        let first = await NewConversationSuggestionCard.performStart(
            suggestion: suggestion,
            conversations: capability,
            sender: sender
        )
        // 首条消息落库：等价于卡片被重建/重启后再次点击时读到的存储状态。
        capability.consumedStarterIDs = [targetID]
        capability.restoreSelection(to: sourceID)
        let second = await NewConversationSuggestionCard.performStart(
            suggestion: suggestion,
            conversations: capability,
            sender: sender
        )

        #expect(first == true)
        #expect(second == true)
        #expect(sender.calls == [targetID], "两次点击合计只发送一次")
    }

    @Test("读取消费状态期间目标被删除：不切换、不发送、返回失败")
    func deletedDuringConsumptionQueryDoesNotSelect() async throws {
        let sourceID = UUID()
        let targetID = UUID()
        let capability = makeCapability(sourceID: sourceID, targetID: targetID, consumed: true)
        capability.beforeConsumptionAnswer = { [weak capability] id in
            capability?.existingConversationIDs.remove(id)
        }
        let sender = ConsumptionStubStarting()

        let opened = await NewConversationSuggestionCard.performStart(
            suggestion: makeSuggestion(targetID),
            conversations: capability,
            sender: sender
        )

        #expect(opened == false)
        #expect(sender.calls.isEmpty)
        #expect(capability.selections.isEmpty, "await 之后身份已变，不得写选中态")
        #expect(capability.selectedConversationID == sourceID)
    }

    @Test("目标已删除时消费判定不参与：仍走 #185 失败路径")
    func deletedTargetStillFailsEvenIfConsumed() async throws {
        let sourceID = UUID()
        let targetID = UUID()
        let capability = makeCapability(sourceID: sourceID, targetID: targetID, consumed: true)
        capability.existingConversationIDs = [sourceID]
        let sender = ConsumptionStubStarting()

        let opened = await NewConversationSuggestionCard.performStart(
            suggestion: makeSuggestion(targetID),
            conversations: capability,
            sender: sender
        )

        #expect(opened == false)
        #expect(sender.calls.isEmpty)
        #expect(capability.selections.isEmpty)
    }

    // MARK: - 出现时的状态校正

    @Test("重建后 idle 卡片按存储校正为已打开（**回归 #632/#592**）")
    func refreshedPhaseShowsOpenedForConsumedTarget() async throws {
        let targetID = UUID()
        let capability = makeCapability(sourceID: UUID(), targetID: targetID, consumed: true)

        let phase = await NewConversationSuggestionCard.refreshedPhase(
            current: .idle,
            suggestion: makeSuggestion(targetID),
            conversations: capability
        )

        #expect(phase == .opened)
    }

    @Test("未消费目标保持 idle，按钮仍可点击")
    func refreshedPhaseKeepsIdleForUnconsumedTarget() async throws {
        let targetID = UUID()
        let capability = makeCapability(sourceID: UUID(), targetID: targetID, consumed: false)

        let phase = await NewConversationSuggestionCard.refreshedPhase(
            current: .idle,
            suggestion: makeSuggestion(targetID),
            conversations: capability
        )

        #expect(phase == .idle)
    }

    @Test("发送失败后的重试态不被误判为已打开")
    func refreshedPhaseKeepsFailedWhenUnconsumed() async throws {
        let targetID = UUID()
        let capability = makeCapability(sourceID: UUID(), targetID: targetID, consumed: false)

        let phase = await NewConversationSuggestionCard.refreshedPhase(
            current: .failed,
            suggestion: makeSuggestion(targetID),
            conversations: capability
        )

        #expect(phase == .failed, "未消费时必须保留重试入口")
    }

    @Test("飞行中的 starting 与终态 opened 不被异步读取回退")
    func refreshedPhaseDoesNotRegressInFlightOrTerminalPhase() async throws {
        let targetID = UUID()
        let consumed = makeCapability(sourceID: UUID(), targetID: targetID, consumed: true)
        let unconsumed = makeCapability(sourceID: UUID(), targetID: targetID, consumed: false)
        let suggestion = makeSuggestion(targetID)

        let starting = await NewConversationSuggestionCard.refreshedPhase(
            current: .starting,
            suggestion: suggestion,
            conversations: consumed
        )
        let opened = await NewConversationSuggestionCard.refreshedPhase(
            current: .opened,
            suggestion: suggestion,
            conversations: unconsumed
        )

        #expect(starting == .starting)
        #expect(opened == .opened)
    }

    @Test("目标已删除时不改写 phase，交给点击路径校验（#185）")
    func refreshedPhaseIgnoresDeletedTarget() async throws {
        let targetID = UUID()
        let capability = makeCapability(sourceID: UUID(), targetID: targetID, consumed: true)
        capability.existingConversationIDs = []

        let phase = await NewConversationSuggestionCard.refreshedPhase(
            current: .idle,
            suggestion: makeSuggestion(targetID),
            conversations: capability
        )

        #expect(phase == .idle)
    }

    @Test("能力缺失时保持原 phase")
    func refreshedPhaseWithoutCapabilityKeepsCurrent() async throws {
        let phase = await NewConversationSuggestionCard.refreshedPhase(
            current: .idle,
            suggestion: makeSuggestion(UUID()),
            conversations: nil
        )

        #expect(phase == .idle)
    }

    // MARK: - 适配层：消费信号来自消息存储

    @Test("适配层按首条用户消息判定已消费，且跨重建保持（**回归 #592**）")
    func adapterDetectsConsumedStarterAcrossRebuild() async throws {
        let manager = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let targetID = try manager.createConversation(
            title: "B",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        messages.insertMessage(
            Message(conversationID: targetID, role: .user, content: "Do an unrelated task here"),
            to: targetID
        )

        let first = NewChatCapabilityAdapter(conversations: manager, messages: messages)
        // 模拟重启：新建适配层，只保留持久化的会话/消息存储。
        let rebuilt = NewChatCapabilityAdapter(conversations: manager, messages: messages)

        #expect(await first.starterAlreadySent(in: targetID))
        #expect(await rebuilt.starterAlreadySent(in: targetID), "重启后仍须识别为已消费")
    }

    @Test("空对话判定为未消费")
    func adapterReportsUnconsumedForEmptyConversation() async throws {
        let manager = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let targetID = try manager.createConversation(
            title: "B",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let adapter = NewChatCapabilityAdapter(conversations: manager, messages: messages)

        #expect(await adapter.starterAlreadySent(in: targetID) == false)
    }

    @Test("只有空白正文或助手消息时不算已消费")
    func adapterIgnoresWhitespaceAndAssistantOnlyMessages() async throws {
        let manager = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let targetID = try manager.createConversation(
            title: "B",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        messages.insertMessage(
            Message(conversationID: targetID, role: .user, content: "   \n"),
            to: targetID
        )
        messages.insertMessage(
            Message(conversationID: targetID, role: .assistant, content: "hi"),
            to: targetID
        )
        let adapter = NewChatCapabilityAdapter(conversations: manager, messages: messages)

        #expect(await adapter.starterAlreadySent(in: targetID) == false)
    }

    @Test("未注入消息存储时退化为未消费，不阻断首次发送")
    func adapterWithoutMessageManagerReportsUnconsumed() async throws {
        let manager = DefaultConversationManager()
        let targetID = try manager.createConversation(
            title: "B",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let adapter = NewChatCapabilityAdapter(conversations: manager)

        #expect(await adapter.starterAlreadySent(in: targetID) == false)
    }
}

// MARK: - 测试替身

/// 记录发送目标的 `NewChatStarting` 替身：始终成功，用于断言「是否真的发送过」。
@MainActor
private final class ConsumptionStubStarting: NewChatStarting {
    private(set) var calls: [UUID] = []

    @discardableResult
    func startIn(conversationID: UUID, content: String) async -> Bool {
        calls.append(conversationID)
        return true
    }
}