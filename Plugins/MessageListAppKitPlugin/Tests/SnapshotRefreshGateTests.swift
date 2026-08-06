import Foundation
import Testing
@testable import MessageListAppKitPlugin

@MainActor
struct SnapshotRefreshGateTests {
    @Test("串行执行：两次 refresh 按顺序执行")
    func serialExecution() async {
        let gate = AppKitSnapshotRefreshGate()
        var order: [Int] = []
        let first = await gate.run {
            try? await Task.sleep(nanoseconds: 20_000_000)
            order.append(1)
            return true
        }
        let second = await gate.run {
            order.append(2)
            return true
        }
        #expect(first == true)
        #expect(second == true)
        #expect(order == [1, 2])
    }

    @Test("重叠请求折叠：活动期间到达的请求只标记一次尾随刷新")
    func overlappingRequestsCollapse() async {
        let gate = AppKitSnapshotRefreshGate()
        let counter = LockedCounter()

        // 主动操作在 I/O 期间（sleep 让出主线程），重叠调用在主线程执行。
        let firstTask = Task { @MainActor in
            await gate.run {
                try? await Task.sleep(nanoseconds: 30_000_000)
                counter.increment()
                return true
            }
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        let overlapping1 = await gate.run {
            counter.increment()
            return true
        }
        let overlapping2 = await gate.run {
            counter.increment()
            return true
        }
        let first = await firstTask.value

        #expect(first == true)
        #expect(overlapping1 == false)
        #expect(overlapping2 == false)
        // 主动 pass（1）+ 尾随 pass（1），重叠请求不额外执行。
        #expect(counter.value == 2)
    }

    @Test("尾随刷新持续到没有新请求到达")
    func trailingRefreshUntilQuiescent() async {
        let gate = AppKitSnapshotRefreshGate()
        let counter = LockedCounter()
        var requestsDuringFirstPass = 2

        let didChange = await gate.run {
            counter.increment()
            if requestsDuringFirstPass > 0 {
                requestsDuringFirstPass -= 1
                // 模拟操作执行期间又有请求到达。
                Task { @MainActor in
                    _ = await gate.run { false }
                }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
            return true
        }

        #expect(didChange == true)
        #expect(counter.value == 3) // 主动 + 2 个尾随 pass
    }

    @Test("重叠调用不获得变更所有权（不返回 true）")
    func overlappingCallerDoesNotOwnChange() async {
        let gate = AppKitSnapshotRefreshGate()
        let firstTask = Task { @MainActor in
            await gate.run {
                try? await Task.sleep(nanoseconds: 30_000_000)
                return true
            }
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        let second = await gate.run { true }
        let first = await firstTask.value
        #expect(first == true)
        #expect(second == false)
    }

    @Test("通知过滤：仅处理所选会话的事件")
    func notificationFilterScopesConversation() {
        let selected = UUID()
        let other = UUID()

        // 未选中会话 → 一律不处理。
        #expect(AppKitMessageNotificationFilter.shouldHandle(
            eventConversationID: nil, selectedConversationID: nil) == false)
        // 无会话 ID 的全局事件 → 处理（legacy 语义）。
        #expect(AppKitMessageNotificationFilter.shouldHandle(
            eventConversationID: nil, selectedConversationID: selected) == true)
        // 匹配会话 → 处理。
        #expect(AppKitMessageNotificationFilter.shouldHandle(
            eventConversationID: selected, selectedConversationID: selected) == true)
        // 其它会话 → 忽略。
        #expect(AppKitMessageNotificationFilter.shouldHandle(
            eventConversationID: other, selectedConversationID: selected) == false)
    }
}

/// Simple reference-counted box for concurrent assertion.
private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
    func increment() {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
    }
}
