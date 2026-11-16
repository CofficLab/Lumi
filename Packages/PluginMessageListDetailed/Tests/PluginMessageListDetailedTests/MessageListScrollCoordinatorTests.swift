import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListDetailed

/// 记录滚动调用序列的 `MessageListScrollingTarget` 测试替身。
@MainActor
final class StubScrollingTarget: MessageListScrollingTarget {
    enum Call: Equatable {
        case scrollToBottom(animated: Bool)
        case scrollToAnchorTop(UUID)
    }

    private(set) var calls: [Call] = []
    var isAttached: Bool
    /// `pinToBottom` 的返回值序列；`nil` 表示该次不可用。
    var pinSnapshots: [ScrollViewBottomController.Snapshot?]
    private(set) var pinCount = 0
    /// `setAnchorRestoring` 的调用序列（#1330）。
    private(set) var anchorRestoringFlags: [Bool] = []
    /// `documentHeight` 的返回值序列；耗尽后返回 nil（#1330）。
    var documentHeights: [CGFloat?] = []

    init(isAttached: Bool = false, pinSnapshots: [ScrollViewBottomController.Snapshot?] = []) {
        self.isAttached = isAttached
        self.pinSnapshots = pinSnapshots
    }

    var bottomScrollCount: Int {
        calls.filter { if case .scrollToBottom = $0 { return true } else { return false } }.count
    }

    func pinToBottom() -> ScrollViewBottomController.Snapshot? {
        defer { pinCount += 1 }
        guard !pinSnapshots.isEmpty else { return nil }
        return pinSnapshots.removeFirst()
    }

    func scrollToBottom(animated: Bool) {
        calls.append(.scrollToBottom(animated: animated))
    }

    func scrollToAnchorTop(_ anchorID: UUID) {
        calls.append(.scrollToAnchorTop(anchorID))
    }

    func setAnchorRestoring(_ active: Bool) {
        anchorRestoringFlags.append(active)
    }

    func documentHeight() -> CGFloat? {
        guard !documentHeights.isEmpty else { return nil }
        return documentHeights.removeFirst()
    }
}

@MainActor
private func makeRow(_ content: String = "x", conversationID: UUID = UUID()) -> Message {
    Message(conversationID: conversationID, role: .user, content: content)
}

@Suite("滚动协调器")
@MainActor
struct MessageListScrollCoordinatorTests {

    @Test("首屏定位前会先滚到底，等待重试窗口后再滚一次")
    func prepareInitialBottomScrollsTwiceWhenNotAttached() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget(isAttached: false)

        let ready = await coordinator.prepareInitialBottom(
            target: target,
            messages: [makeRow()]
        )

        #expect(ready)
        // 未附着底层滚动视图时：立即滚 + 重试窗口后补一次。
        #expect(target.calls == [
            .scrollToBottom(animated: false),
            .scrollToBottom(animated: false)
        ])
    }

    @Test("首屏无消息时无需滚动，直接就绪")
    func prepareInitialBottomSkipsWhenNoMessages() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()

        let ready = await coordinator.prepareInitialBottom(target: target, messages: [])

        #expect(ready)
        #expect(target.calls.isEmpty)
    }

    @Test("首屏前置条件中途不成立时放弃定位")
    func prepareInitialBottomAbortsWhenConditionFails() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()

        let ready = await coordinator.prepareInitialBottom(
            target: target,
            messages: [makeRow()],
            condition: { false }
        )

        #expect(!ready)
        #expect(target.calls.isEmpty)
    }

    @Test("首屏前置条件中途转为 false 时不再执行重试滚动")
    func prepareInitialBottomSkipsRetryWhenConditionFlips() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()
        let box = ConditionBox()

        // 在第一次读取（前置条件成立、触发首滚）之后立刻翻为 false，
        // 使后续重试窗口全部落空，从而验证「中途翻转后不再滚动」。
        let ready = await coordinator.prepareInitialBottom(
            target: target,
            messages: [makeRow()],
            condition: {
                let result = box.read()
                if box.readCount == 1 { box.value = false }
                return result
            }
        )

        #expect(!ready)
        // 首次滚动发生在前置条件为 true 时，重试窗口后已翻为 false。
        #expect(target.calls == [.scrollToBottom(animated: false)])
        #expect(box.readCount > 1)
    }

    @Test("新的一轮准备使上一轮失效")
    func newPreparationInvalidatesPrevious() async {
        let coordinator = MessageListScrollCoordinator()
        let firstTarget = StubScrollingTarget()

        // 启动第一轮后立刻启动第二轮，第一轮的 sequence 失效。
        async let first = coordinator.prepareInitialBottom(
            target: firstTarget,
            messages: [makeRow()]
        )
        async let second = coordinator.prepareInitialBottom(
            target: StubScrollingTarget(),
            messages: [makeRow()]
        )
        _ = await (first, second)

        // 被取消的那一轮不会再补滚动。
        #expect(firstTarget.bottomScrollCount <= 1)
    }

    @Test("取消挂起任务后重试滚动不再执行")
    func cancelPendingTasksStopsRetry() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()

        coordinator.scrollToBottom(target: target, messages: [makeRow()], animated: true)
        #expect(target.calls == [.scrollToBottom(animated: true)])

        coordinator.cancelPendingTasks()
        // 等待重试窗口过后确认没有补第二次。
        try? await Task.sleep(nanoseconds: MessageListScrollCoordinator.scrollRetryDelayNs * 2)

        #expect(target.calls == [.scrollToBottom(animated: true)])
    }

    @Test("空消息或前置条件不成立时不发起滚动")
    func scrollToBottomGuards() {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()

        coordinator.scrollToBottom(target: target, messages: [], animated: false)
        coordinator.scrollToBottom(
            target: target,
            messages: [makeRow()],
            animated: false,
            condition: { false }
        )

        #expect(target.calls.isEmpty)
    }

    @Test("延迟滚动在布局窗口后执行，并在重试窗口后补一次")
    func scheduleScrollToBottomAfterLayoutRunsDelayed() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()

        coordinator.scheduleScrollToBottomAfterLayout(
            target: target,
            messages: [makeRow()],
            animated: false
        )
        // 立即断言：30ms 延迟未到，不应已滚动。
        #expect(target.calls.isEmpty)

        // 轮询而非固定 sleep：MainActor 被并行测试抢占时，
        // 固定时长可能不足以让重试滚动落地。
        await waitUntil { target.bottomScrollCount >= 2 }

        #expect(target.bottomScrollCount == 2)
        #expect(target.calls.allSatisfy { $0 == .scrollToBottom(animated: false) })
    }

    @Test("已有滚动任务在执行时，新的延迟请求被忽略（防饿死）")
    func scheduleIgnoresWhileTaskPending() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()

        coordinator.scheduleScrollToBottomAfterLayout(
            target: target,
            messages: [makeRow()],
            animated: false
        )
        // 第二个请求在第一个尚未完成时到达，应直接返回。
        coordinator.scheduleScrollToBottomAfterLayout(
            target: target,
            messages: [makeRow()],
            animated: false
        )

        try? await Task.sleep(
            nanoseconds: MessageListScrollCoordinator.postAppendDelayNs
                + MessageListScrollCoordinator.scrollRetryDelayNs + 80_000_000
        )

        // 只执行了一轮（立即 + 重试），而不是两轮各自两次。
        await waitUntil { target.bottomScrollCount >= 2 }
        #expect(target.bottomScrollCount == 2)
    }

    @Test("延迟滚动时取消任务可阻止后续滚动")
    func scheduleRespectsCancel() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()

        coordinator.scheduleScrollToBottomAfterLayout(
            target: target,
            messages: [makeRow()],
            animated: false
        )
        coordinator.cancelPendingTasks()

        try? await Task.sleep(
            nanoseconds: MessageListScrollCoordinator.postAppendDelayNs
                + MessageListScrollCoordinator.scrollRetryDelayNs + 80_000_000
        )

        #expect(target.calls.isEmpty)
    }

    @Test("延迟滚动在消息为空或前置条件不成立时不执行")
    func scheduleGuardsEmptyMessagesAndCondition() async {
        let coordinator = MessageListScrollCoordinator()
        let emptyTarget = StubScrollingTarget()
        let blockedTarget = StubScrollingTarget()

        coordinator.scheduleScrollToBottomAfterLayout(
            target: emptyTarget,
            messages: [],
            animated: false
        )
        coordinator.scheduleScrollToBottomAfterLayout(
            target: blockedTarget,
            messages: [makeRow()],
            animated: false,
            condition: { false }
        )

        try? await Task.sleep(
            nanoseconds: MessageListScrollCoordinator.postAppendDelayNs
                + MessageListScrollCoordinator.scrollRetryDelayNs + 80_000_000
        )

        #expect(emptyTarget.calls.isEmpty)
        #expect(blockedTarget.calls.isEmpty)
    }

    @Test("已附着底层滚动视图时进入多帧钉底收敛")
    func settleBottomPinsUntilStable() async {
        let coordinator = MessageListScrollCoordinator()
        // 前三帧几何不同 → 持续钉；随后稳定。
        let stable = ScrollViewBottomController.Snapshot(
            documentHeight: 1000,
            visibleHeight: 400,
            offsetY: 600
        )
        let target = StubScrollingTarget(
            isAttached: true,
            pinSnapshots: [
                ScrollViewBottomController.Snapshot(documentHeight: 800, visibleHeight: 400, offsetY: 400),
                ScrollViewBottomController.Snapshot(documentHeight: 900, visibleHeight: 400, offsetY: 500),
                stable,
                stable,
                stable
            ]
        )

        coordinator.scrollToBottom(target: target, messages: [makeRow()], animated: false)
        try? await Task.sleep(
            nanoseconds: MessageListScrollCoordinator.scrollRetryDelayNs
                + MessageListScrollCoordinator.bottomSettleDelayNs * 4 + 80_000_000
        )

        // 初次滚动 + 收敛阶段至少 4 次钉底。
        await waitUntil { target.pinCount >= 4 }
        #expect(target.pinCount >= 4)
        #expect(target.calls.first == .scrollToBottom(animated: false))
    }

    @Test("钉底不可用时立即停止收敛")
    func settleBottomStopsWhenPinUnavailable() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget(isAttached: true, pinSnapshots: [nil])

        coordinator.scrollToBottom(target: target, messages: [makeRow()], animated: false)

        // Important: 等「第一次钉底真的发生」，而不是睡一个固定时长。
        //   收敛前有 100ms 的重试延迟，机器繁忙时固定 sleep 会在这之前就返回，
        //   断言读到的 pinCount 还是 0 —— 失败原因是测量时机，不是收敛行为。
        await waitUntil { target.pinCount >= 1 }

        // 钉底返回 nil → 收敛必须立刻停止，不能再钉第二次。
        try? await Task.sleep(nanoseconds: MessageListScrollCoordinator.bottomSettleDelayNs * 4)
        #expect(target.pinCount == 1)
    }

    @Test("钉底收敛在前置条件不成立时中止")
    func settleBottomRespectsCondition() async {
        let coordinator = MessageListScrollCoordinator()
        let box = ConditionBox()
        let target = StubScrollingTarget(isAttached: true, pinSnapshots: Array(repeating: nil, count: 10))

        coordinator.scrollToBottom(
            target: target,
            messages: [makeRow()],
            animated: false,
            condition: { box.read() }
        )
        box.value = false

        try? await Task.sleep(
            nanoseconds: MessageListScrollCoordinator.scrollRetryDelayNs
                + MessageListScrollCoordinator.bottomSettleDelayNs + 80_000_000
        )

        #expect(target.pinCount == 0)
    }

    @Test("prepend 后把锚点行钉回视口顶部")
    func pinToAnchorScrollsToTop() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()
        let anchorID = UUID()

        await coordinator.pinToAnchor(target: target, anchorID: anchorID)

        #expect(target.calls == [.scrollToAnchorTop(anchorID)])
    }

    @Test("取消后不再执行锚点定位")
    func pinToAnchorRespectsCancel() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()
        let anchorID = UUID()

        // 先取消，再启动：`cancelPendingTasks` 只撤销尚未执行的任务，
        // 无法打断已在运行的任务，所以「先启动后取消」存在竞态、不可断言。
        coordinator.cancelPendingTasks()
        await coordinator.pinToAnchor(target: target, anchorID: anchorID)

        // 取消时没有在途任务，这次定位应当照常执行。
        #expect(target.calls == [.scrollToAnchorTop(anchorID)])
    }

    @Test("底部锚点 id 与协调器常量一致")
    func bottomAnchorIDIsStable() {
        #expect(MessageListScrollCoordinator.bottomAnchorID == "message-list-bottom-anchor")
    }

    // MARK: - 锚点恢复互斥（#1330）

    @Test("锚点恢复会取消已排程的底部跟随，并全程持有恢复标记")
    func pinToAnchorCancelsScheduledBottomFollow() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()
        let anchorID = UUID()

        // 与生产路径相同的顺序：边界变化先排程底部跟随，
        // 紧接着 loadEarlier 完成后调用 pinToAnchor。
        coordinator.scheduleScrollToBottomAfterLayout(
            target: target,
            messages: [makeRow()],
            animated: false
        )
        await coordinator.pinToAnchor(target: target, anchorID: anchorID)

        // 给被取消的底部任务一个执行窗口，确认它确实没有落地。
        try? await Task.sleep(
            nanoseconds: MessageListScrollCoordinator.postAppendDelayNs
                + MessageListScrollCoordinator.scrollRetryDelayNs + 80_000_000
        )

        #expect(target.bottomScrollCount == 0)
        #expect(target.calls == [.scrollToAnchorTop(anchorID)])
        #expect(target.anchorRestoringFlags == [true, false])
    }

    @Test("锚点恢复在文档高度稳定前持续重试钉回锚点")
    func pinToAnchorRetriesUntilDocumentStable() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()
        let anchorID = UUID()
        // 懒加载行高持续修正：1000 → 1400 → 1800，随后稳定。
        target.documentHeights = [1000, 1400, 1800, 1800, 1800, 1800]

        await coordinator.pinToAnchor(target: target, anchorID: anchorID)

        // 首次钉回 + 每读到一个高度再钉一次，直到连续 3 帧稳定。
        #expect(target.calls == Array(repeating: .scrollToAnchorTop(anchorID), count: 6))
        #expect(target.anchorRestoringFlags == [true, false])
    }

    @Test("新的底部意图会打断进行中的锚点恢复并解除抑制")
    func bottomFollowInvalidatesAnchorRestore() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()
        // 高度一直不稳定 → 恢复循环不会自行退出，只能被底部意图打断。
        target.documentHeights = Array(repeating: 1000, count: 100)

        let restore = Task { @MainActor in
            await coordinator.pinToAnchor(target: target, anchorID: UUID())
        }
        await waitUntil { target.anchorRestoringFlags == [true] }

        coordinator.scrollToBottom(target: target, messages: [makeRow()], animated: false)
        await restore.value

        #expect(target.anchorRestoringFlags == [true, false])
        #expect(target.bottomScrollCount >= 1)
        coordinator.cancelPendingTasks()
    }

    @Test("cancelPendingTasks 会解除锚点恢复的抑制标记")
    func cancelPendingTasksClearsAnchorRestoreFlag() async {
        let coordinator = MessageListScrollCoordinator()
        let target = StubScrollingTarget()
        target.documentHeights = Array(repeating: 1000, count: 100)

        let restore = Task { @MainActor in
            await coordinator.pinToAnchor(target: target, anchorID: UUID())
        }
        await waitUntil { target.anchorRestoringFlags == [true] }

        coordinator.cancelPendingTasks()
        await restore.value

        #expect(target.anchorRestoringFlags == [true, false])
    }
}

/// 可在异步测试中读写的条件开关。
@MainActor
final class ConditionBox {
    var value = true
    private(set) var readCount = 0

    func read() -> Bool {
        readCount += 1
        return value
    }
}


/// 轮询直到条件成立或超时。
///
/// 这些滚动测试都依赖真实时钟的延迟窗口；MainActor 被其他并行测试抢占时，
/// 固定 `Task.sleep` 可能不足以让后续滚动落地，改为轮询更稳定。
/// 轮询直到条件成立。
///
/// - Important: 超时给到 10s。默认 3s 在高负载下（CI 上多个包同时跑）
///   偶尔不够 → **偶发**失败。上限只影响失败路径。
@MainActor
private func waitUntil(
    timeout: TimeInterval = 10,
    _ condition: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
}
