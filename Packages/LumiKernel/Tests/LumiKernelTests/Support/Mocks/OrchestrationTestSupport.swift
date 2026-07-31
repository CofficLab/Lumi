import Foundation
@testable import LumiKernel

// MARK: - OrchestrationEventLog

/// 线程安全的事件日志。
///
/// `MessageManaging` 的读方法是非隔离的(可在后台线程被调),写方法是
/// `@MainActor` 的,mock 的存储统一用锁保护。用于断言"先 A 后 B"的调用顺序。
final class OrchestrationEventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [String] = []

    var events: [String] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    func record(_ event: String) {
        lock.lock(); defer { lock.unlock() }
        _events.append(event)
    }
}

// MARK: - TurnGate

/// 让 `MockAgentTurnManager.runTurn` 挂起直到 `release()`。
///
/// 用于测试挂起/队列场景:首回合被它挂住期间,第二次发送会进入待发送队列,
/// 模拟"会话正在发送中"。**用完即弃**:跨回合重置时需新建实例,否则旧
/// continuation 永不 resume 会导致死等。
@MainActor
final class TurnGate {
    private var continuation: CheckedContinuation<Void, Never>?

    /// 在 runTurn 内 await:挂起直到 release。
    func wait() async {
        await withCheckedContinuation { self.continuation = $0 }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
