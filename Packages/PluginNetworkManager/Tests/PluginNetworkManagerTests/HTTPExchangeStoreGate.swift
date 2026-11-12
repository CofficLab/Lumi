import Foundation
import Testing

/// 跨 suite 的异步互斥门。
///
/// `NetworkService.shared.currentExchangeStore` 是**进程级单例**上的可变状态，
/// 只有一份。多个 suite 并发执行时无法各自持有独立的 store——它们会互相把
/// 指针抢走。
///
/// 具体表现：`HTTPSummaryToolLimitTests` 注入了临时 store，另一个 suite 的
/// `NetworkManagerPlugin.onShutdown`（`configureHTTPExchangeStore(nil)`）在
/// 它读之前把 store 清成 nil，于是查询工具报
/// "HTTP exchange store not available"。
///
/// - Note: Swift Testing 的 `.serialized` 只在**单个 suite 内部**生效，
///   兄弟 suite 仍然可以并行执行。
actor HTTPExchangeStoreGate {
    static let shared = HTTPExchangeStoreGate()

    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// 等待进入临界区。
    func enter() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// 离开临界区，唤醒下一个等待者。
    func leave() {
        if waiters.isEmpty {
            isHeld = false
            return
        }
        waiters.removeFirst().resume()
    }
}

/// Swift Testing 的作用域 trait：进入 suite 时独占 HTTP exchange store，
/// 退出时释放。
///
/// - Important: Swift Testing 的 `SuiteTrait` **没有** `setUp` 钩子——
///   在 trait 上写 `setUp` 只会得到一个永远不被调用的普通方法。
///   正确的做法是实现 `TestScoping`，用 `provideScope` 接管。
struct HTTPExchangeStoreGateTrait: TestScoping, SuiteTrait {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        await HTTPExchangeStoreGate.shared.enter()
        defer { Task { await HTTPExchangeStoreGate.shared.leave() } }
        try await function()
    }
}
