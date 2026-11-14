import Foundation
import Testing
@testable import ProviderLLMManager

/// 跨 suite 的异步互斥门。
///
/// `LLMManagerUserDefaults.current` 是**进程级静态状态**，只有一个指针。
/// 两个 suite 并发运行时无法各自指向不同的偏好域——它们会互相把指针抢走。
/// 因此需要让"接管偏好域"这件事**跨 suite 串行**。
///
/// - Note: Swift Testing 的 `.serialized` 只在**单个 suite 内部**生效，
///   两个兄弟 suite 仍然可以并行执行。
actor LLMManagerDefaultsGate {
    static let shared = LLMManagerDefaultsGate()

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

/// 进程级的偏好域隔离协调器。
///
/// `LLMManagerUserDefaults.current` 是**进程级静态状态**，且
/// `DefaultLLMProviderManagerProviding.init()` 会从它读取"上次选中的模型"
/// 作为初始选中态。于是任何残留值都会让用例读到错误的初始状态。
///
/// 隔离要解决两件事：
///
/// 1. **残留泄漏**：上一个用例写入的选中态泄漏到下一个用例。
///    → 进入临界区时清空被管理的键。
/// 2. **并发互踩**：不同 suite 并行执行时互相把 `current` 抢走，
///    导致某个用例读到开发者本机的真实偏好 → 随机失败。
///    → 用 `LLMManagerDefaultsGate` 把"接管偏好域"跨 suite 串行化。
enum LLMManagerDefaultsIsolation {
    /// 参与隔离的偏好键。进入临界区时清空，保证断言从干净状态开始。
    static let keys: [String] = [
        "com.coffic.lumi.llmProviderManager.selectedModelID",
        "com.coffic.lumi.llmProviderManager.selectedProviderID",
        "com.coffic.lumi.llmProviderManager.selectedModel",
    ]

    // 全部状态都由 `lock` 保护；Swift 6 对可变全局状态要求显式标注。
    nonisolated(unsafe) private static let lock = NSLock()
    private static let suiteName = "com.coffic.lumi.test.llm-manager.shared"
    nonisolated(unsafe) private static let shared: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("无法创建隔离的 UserDefaults（suite: \(suiteName)）")
        }
        return defaults
    }()

    /// 接管偏好域。调用方必须在退出临界区时调用 `release()`。
    static func acquire() -> UserDefaults {
        lock.lock()
        defer { lock.unlock() }

        for key in keys {
            shared.removeObject(forKey: key)
        }
        LLMManagerUserDefaults.current = shared
        return shared
    }

    /// 释放接管，把偏好域还原回 `.standard`。
    static func release() {
        lock.lock()
        defer { lock.unlock() }

        for key in keys {
            shared.removeObject(forKey: key)
        }
        LLMManagerUserDefaults.current = .standard
    }
}

/// Swift Testing 的作用域 trait：进入 suite 时接管偏好域，退出时还原。
///
/// - Important: `SuiteTrait` **没有** `setUp` 钩子——在 trait 上写 `setUp`
///   只会得到一个永远不被调用的普通方法，隔离因此完全失效。
///   正确的做法是实现 `TestScoping`，用 `provideScope` 接管。
/// - Important: `provideScope` 对 **SuiteTrait** 是**suite 级**调用
///   （整个 suite 的用例共享一次接管），因此 suite 内部可以安全地共享同一份
///   隔离域；suite **之间**则由 `LLMManagerDefaultsGate` 串行化。
struct LLMManagerDefaultsTrait: TestScoping, SuiteTrait {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        await LLMManagerDefaultsGate.shared.enter()
        _ = LLMManagerDefaultsIsolation.acquire()
        defer {
            LLMManagerDefaultsIsolation.release()
            Task { await LLMManagerDefaultsGate.shared.leave() }
        }
        try await function()
    }
}
