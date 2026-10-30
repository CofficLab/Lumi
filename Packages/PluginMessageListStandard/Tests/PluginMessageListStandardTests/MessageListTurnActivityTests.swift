import Foundation
import ProviderAgentLoop
import ProviderDeveloperMode
import ProviderMessage
import ProviderToolManager
import Testing
@testable import PluginMessageListStandard

// MARK: - TurnActivity

@MainActor
@Test("Turn 活动按开始时间升序排序，时间相同按 id 稳定排序")
func turnActivitySortsToolCallsStably() {
    let turnID = UUID()
    let conversationID = UUID()
    let sameInstant = Date(timeIntervalSince1970: 1_000)

    let later = makeToolCallRecord(id: "c", conversationID: conversationID, startedAt: sameInstant)
    let earlier = makeToolCallRecord(id: "z", conversationID: conversationID, startedAt: sameInstant.addingTimeInterval(-10))
    let tieA = makeToolCallRecord(id: "a", conversationID: conversationID, startedAt: sameInstant)
    let tieB = makeToolCallRecord(id: "b", conversationID: conversationID, startedAt: sameInstant)

    let activity = TurnActivityBuilder.build(
        turnID: turnID,
        conversationID: conversationID,
        state: .idle,
        toolCalls: [tieB, later, earlier, tieA]
    )

    #expect(activity.id == turnID)
    #expect(activity.conversationID == conversationID)
    #expect(activity.state == .idle)
    // earlier 最早；同一时刻内按 id 升序 → a 在 b 之前
    #expect(activity.toolCalls.map(\.id) == ["z", "a", "b", "c"])
}

@MainActor
@Test("Turn 活动统计总数、完成数、失败数与总时长")
func turnActivitySummarisesRecords() {
    let conversationID = UUID()
    let activity = LumiTurnActivity(
        id: UUID(),
        conversationID: conversationID,
        state: .running,
        toolCalls: [
            makeToolCallRecord(id: "ok", conversationID: conversationID, duration: 1.5),
            makeToolCallRecord(id: "done", conversationID: conversationID, completed: true, duration: 2.5),
            makeToolCallRecord(id: "bad", conversationID: conversationID, completed: true, duration: 1.0, isError: true),
        ]
    )

    #expect(activity.totalCount == 3)
    #expect(activity.completedCount == 2)
    #expect(activity.failedCount == 1)
    #expect(activity.totalDuration == 5.0)
}

@MainActor
@Test("Turn 活动无完成记录时总时长为 nil，失败计数不重复计入完成数")
func turnActivityHandlesEmptyAndUnfinished() {
    let conversationID = UUID()
    let pending = LumiTurnActivity(
        id: UUID(),
        conversationID: conversationID,
        state: .running,
        toolCalls: [makeToolCallRecord(id: "running", conversationID: conversationID, duration: nil)]
    )

    #expect(pending.totalCount == 1)
    #expect(pending.completedCount == 0)
    #expect(pending.failedCount == 0)
    #expect(pending.totalDuration == nil)

    let empty = LumiTurnActivity(
        id: UUID(),
        conversationID: conversationID,
        state: .idle,
        toolCalls: []
    )
    #expect(empty.totalCount == 0)
    #expect(empty.totalDuration == nil)
}

// MARK: - Message derived predicates

@Test("isToolExecutionOnly 仅对空白或省略号正文且带工具调用的助手消息成立")
func toolExecutionOnlyPredicateIsNarrow() {
    let conversationID = UUID()
    let calls = [MessageToolCall(id: "c1", name: "read", arguments: "{}")]

    #expect(message(role: .assistant, content: "", calls: calls).isToolExecutionOnly)
    #expect(message(role: .assistant, content: "  \n ", calls: calls).isToolExecutionOnly)
    #expect(message(role: .assistant, content: "...", calls: calls).isToolExecutionOnly)

    // 正文有实质内容 → 不是纯工具执行
    #expect(!message(role: .assistant, content: "done", calls: calls).isToolExecutionOnly)
    // 非助手角色 → 不是
    #expect(!message(role: .user, content: "", calls: calls).isToolExecutionOnly)
    #expect(!message(role: .tool, content: "", calls: calls).isToolExecutionOnly)
    // 无工具调用 → 不是
    #expect(!message(role: .assistant, content: "", calls: nil).isToolExecutionOnly)
    #expect(!message(role: .assistant, content: "", calls: []).isToolExecutionOnly)
}

@Test("isEmptyResponse 排除错误消息与带工具调用的消息")
func emptyResponsePredicateExcludesErrorAndTools() {
    let calls = [MessageToolCall(id: "c1", name: "read", arguments: "{}")]

    #expect(message(role: .assistant, content: "").isEmptyResponse)
    #expect(message(role: .assistant, content: " \n\t ").isEmptyResponse)
    #expect(!message(role: .assistant, content: "hi").isEmptyResponse)
    #expect(!message(role: .assistant, content: "", isError: true).isEmptyResponse)
    #expect(!message(role: .assistant, content: "", calls: calls).isEmptyResponse)
}

// MARK: - Developer mode state

@MainActor
@Test("开发者模式状态只传播真实变化，避免无效刷新")
func developerModeStateOnlyPublishesRealChanges() async {
    let viewModel = DeveloperModeStateViewModel()
    #expect(!viewModel.isDeveloperModeEnabled)

    // @Published 的 sink 在订阅时立即投递当前值（Combine 语义）。
    var observed: [Bool] = []
    let observer = viewModel.$isDeveloperModeEnabled.sink { observed.append($0) }
    defer { observer.cancel() }
    #expect(observed == [false], "订阅时应收到一次当前值")

    viewModel.update(isDeveloperModeEnabled: false) // 重复值：不应产生新发布
    #expect(observed == [false], "重复值不应触发发布")

    viewModel.update(isDeveloperModeEnabled: true)
    #expect(viewModel.isDeveloperModeEnabled)
    #expect(observed == [false, true])
}

@MainActor
@Test("开发者模式观察器把外部初始值与变更事件写入共享状态")
func developerModeObserverBridgesProviderEvents() async {
    let provider = FakeDeveloperModeProvider(initialEnabled: true)
    let viewModel = DeveloperModeStateViewModel()

    let observer = DeveloperModeStateObserver(provider: provider, viewModel: viewModel)
    #expect(viewModel.isDeveloperModeEnabled, "初始值应立即同步")

    provider.emit(.enabledChanged(false))
    #expect(!viewModel.isDeveloperModeEnabled)

    provider.emit(.enabledChanged(true))
    #expect(viewModel.isDeveloperModeEnabled)

    observer.cancel()
    #expect(provider.observerCancelled)
    // 取消后事件不应再影响状态
    provider.emit(.enabledChanged(false))
    #expect(viewModel.isDeveloperModeEnabled)
}

@MainActor
@Test("开发者模式观察器在 provider 缺失时按未启用处理")
func developerModeObserverToleratesMissingProvider() {
    let viewModel = DeveloperModeStateViewModel()
    let observer = DeveloperModeStateObserver(provider: nil, viewModel: viewModel)
    #expect(!viewModel.isDeveloperModeEnabled)
    observer.cancel()
}

// MARK: - Helpers

private func message(
    role: MessageRole,
    content: String,
    isError: Bool = false,
    calls: [MessageToolCall]? = nil
) -> Message {
    Message(
        conversationID: UUID(),
        role: role,
        content: content,
        isError: isError,
        toolCalls: calls
    )
}

/// `DeveloperModeProviding` 的可编程假实现。
@MainActor
final class FakeDeveloperModeProvider: DeveloperModeProviding {
    private(set) var isEnabled: Bool
    private(set) var observerCancelled = false
    private(set) var setEnabledCalls: [Bool] = []
    private(set) var toggleCount = 0
    private var handlers: [UUID: (DeveloperModeProvidingEvent) -> Void] = [:]

    init(initialEnabled: Bool) { self.isEnabled = initialEnabled }

    func setEnabled(_ enabled: Bool) {
        setEnabledCalls.append(enabled)
        isEnabled = enabled
    }

    func toggle() { toggleCount += 1 }

    func addObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle {
        let token = UUID()
        handlers[token] = callback
        // 取消必须真正摘除 handler，否则无法验证「取消后不再收到事件」。
        return Handle { [weak self] in
            guard let self else { return }
            self.observerCancelled = true
            self.handlers.removeValue(forKey: token)
        }
    }

    func emit(_ event: DeveloperModeProvidingEvent) {
        handlers.values.forEach { $0(event) }
    }

    final class Handle: DeveloperModeProvidingObserverHandle {
        private let onCancel: () -> Void
        init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
        func cancel() { onCancel() }
    }
}
