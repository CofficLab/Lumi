import Foundation

/// 串行化「向 `NotificationCenter.default` 投递通知并断言」的过程。
///
/// `NotificationCenter.default` 是进程级共享资源：包内既有的
/// `UpdateRequestObserverTests` 与新增的通知用例都会投递 `.checkForUpdates`
/// 和 `.installPreparedAppUpdate` 这两个同名通知，并发投递会让双方的计数互相
/// 污染。Swift Testing 的 `.serialized` 只在 suite 内部串行，无法隔离不同
/// suite，因此这里加一把显式的门闩。
@MainActor
enum AppUpdateNotificationGate {
    private static var isHeld = false
    private static var waiters: [CheckedContinuation<Void, Never>] = []

    /// 获取门闩。调用方必须配对调用 `release()`。
    static func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// 释放门闩，交给下一个等待者。
    static func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
