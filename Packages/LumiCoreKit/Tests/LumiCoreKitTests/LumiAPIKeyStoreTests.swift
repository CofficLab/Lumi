import Foundation
import Security
@testable import LumiCoreKit
import Testing

@Suite("LumiAPIKeyStore", .serialized)
struct LumiAPIKeyStoreTests {

    // MARK: - 正常路径

    @Test func successReturnsValue() {
        let backend = MockKeychainBackend(readResults: [
            .init(data: Data("sk-deepseek".utf8), status: errSecSuccess)
        ])
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })

        #expect(store.string(forKey: "DevAssistant_ApiKey_DeepSeek") == "sk-deepseek")
        #expect(backend.readCount == 1)
    }

    @Test func emptyKeyReturnsNilWithoutBackendCall() {
        let backend = MockKeychainBackend()
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })

        #expect(store.string(forKey: "") == nil)
        #expect(backend.readCount == 0)
    }

    // MARK: - 真「未配置」：不重试

    @Test func itemNotFoundReturnsNilWithoutRetry() {
        let backend = MockKeychainBackend(readResults: [
            .init(data: nil, status: errSecItemNotFound)
        ])
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })

        // 项不存在 = 真未配置，应立即返回 nil，不浪费重试
        #expect(store.string(forKey: "DevAssistant_ApiKey_DeepSeek") == nil)
        #expect(backend.readCount == 1, "missing 不应触发重试")
    }

    // MARK: - ★ 复现并修复 bug：瞬时失败 → 重试 → 成功 ★

    @Test func transientFailureThenSuccessReturnsValue() {
        // 模拟 securityd 抖动：第 1 次 errSecInteractionNotAllowed，第 2 次成功
        // 修复前：string(forKey:) 直接吞成 nil（bug）
        // 修复后：静默重试后返回正确值
        let backend = MockKeychainBackend(readResults: [
            .init(data: nil, status: errSecInteractionNotAllowed),
            .init(data: Data("sk-recovered".utf8), status: errSecSuccess),
        ])
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })

        #expect(store.string(forKey: "DevAssistant_ApiKey_DeepSeek") == "sk-recovered")
        #expect(backend.readCount == 2)
    }

    @Test func authFailedThenSuccessAlsoRetries() {
        // errSecAuthFailed 同属瞬时错误，也应重试
        let backend = MockKeychainBackend(readResults: [
            .init(data: nil, status: errSecAuthFailed),
            .init(data: Data("sk-ok".utf8), status: errSecSuccess),
        ])
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })

        #expect(store.string(forKey: "k") == "sk-ok")
        #expect(backend.readCount == 2)
    }

    // MARK: - 重试上限：持续失败最终返回 nil（不卡死）

    @Test func persistentTransientFailureReturnsNilAfterMaxAttempts() {
        // 持续瞬时失败：应在达到上限后返回 nil，而非无限重试
        let alwaysFailing = MockKeychainBackend(repeatingRead: .init(data: nil, status: errSecInteractionNotAllowed))
        let store = LumiAPIKeyStore(backend: alwaysFailing, sleeper: { _ in })

        #expect(store.string(forKey: "k") == nil)
        #expect(alwaysFailing.readCount == LumiAPIKeyStore.maxTransientAttempts)
    }

    // MARK: - 退避节奏（sleeper 应被调用、且为指数退避）

    @Test func retryUsesExponentialBackoff() {
        let delays = BackoffCollector()
        let backend = MockKeychainBackend(repeatingRead: .init(data: nil, status: errSecInteractionNotAllowed))
        let store = LumiAPIKeyStore(backend: backend, sleeper: delays.record)

        _ = store.string(forKey: "k")

        // 4 次尝试 → 3 次 sleep（最后一次失败后不再 sleep）
        #expect(delays.recorded == [
            LumiAPIKeyStore.transientRetryDelayNanoseconds(for: 0),  // 50ms
            LumiAPIKeyStore.transientRetryDelayNanoseconds(for: 1),  // 100ms
            LumiAPIKeyStore.transientRetryDelayNanoseconds(for: 2),  // 200ms
        ])
    }

    @Test func backoffDoublesEachAttempt() {
        // 锁定退避节奏：50ms → 100ms → 200ms
        #expect(LumiAPIKeyStore.transientRetryDelayNanoseconds(for: 0) == 50_000_000)
        #expect(LumiAPIKeyStore.transientRetryDelayNanoseconds(for: 1) == 100_000_000)
        #expect(LumiAPIKeyStore.transientRetryDelayNanoseconds(for: 2) == 200_000_000)
        #expect(LumiAPIKeyStore.transientRetryDelayNanoseconds(for: 3) == 400_000_000)
    }

    // MARK: - 写入 / 删除

    @Test func writeStoresTrimmedValue() {
        let backend = MockKeychainBackend()
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })

        store.set("  sk-spaces  \n", forKey: "k")

        #expect(backend.written.first?.data == Data("sk-spaces".utf8))
    }

    @Test func writeEmptyStringRemovesItem() {
        let backend = MockKeychainBackend()
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })

        store.set("   ", forKey: "k")

        #expect(backend.writeCount == 0)
        #expect(backend.deleteCount == 1)
    }

    @Test func removeCallsBackendDelete() {
        let backend = MockKeychainBackend()
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })

        store.remove(forKey: "k")

        #expect(backend.deleteCount == 1)
    }

    // MARK: - 旧数据迁移（用隔离的 key + defer 清理，避免污染真实 UserDefaults）

    @Test func migrationFallsBackToUserDefaultsThenWritesKeychain() {
        let testKey = "DevAssistant_ApiKey_MigrationTest_\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: testKey) }

        // backend 里该项不存在（missing），UserDefaults 有旧值
        let backend = MockKeychainBackend(repeatingRead: .init(data: nil, status: errSecItemNotFound))
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })
        UserDefaults.standard.set("legacy-key", forKey: testKey)

        let value = store.loadMigratingLegacyUserDefaults(forKey: testKey)

        #expect(value == "legacy-key")
        #expect(backend.written.first?.data == Data("legacy-key".utf8), "应把旧值迁到 Keychain")
        #expect(UserDefaults.standard.string(forKey: testKey) == nil, "迁移后应删除 UserDefaults 旧值")
    }

    @Test func migrationPrefersKeychainValue() {
        let testKey = "DevAssistant_ApiKey_MigrationTest_\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: testKey)
        }

        // Keychain 已有值 → 优先用，不碰 UserDefaults
        let backend = MockKeychainBackend(repeatingRead: .init(data: Data("kc-key".utf8), status: errSecSuccess))
        let store = LumiAPIKeyStore(backend: backend, sleeper: { _ in })
        UserDefaults.standard.set("legacy-key", forKey: testKey)

        let value = store.loadMigratingLegacyUserDefaults(forKey: testKey)

        #expect(value == "kc-key")
        #expect(backend.writeCount == 0, "Keychain 已有值时不应触发写入")
    }
}

// MARK: - 测试用 Mock

/// 可记录调用次数、按预设序列返回读取结果的 Keychain backend 替身。
private final class MockKeychainBackend: LumiKeychainBackend, @unchecked Sendable {
    private let readResults: [LumiKeychainReadResult]
    private let repeatingRead: LumiKeychainReadResult?
    private let lock = NSLock()

    private(set) var readCount = 0
    private(set) var written: [(data: Data, service: String, account: String)] = []
    private(set) var writeCount = 0
    private(set) var deleteCount = 0

    /// 序列模式：按 readResults 顺序返回；超出长度时返回最后一个（或未提供则 errSecItemNotFound）。
    init(readResults: [LumiKeychainReadResult] = []) {
        self.readResults = readResults
        self.repeatingRead = nil
    }

    /// 恒定模式：每次读取都返回同一结果。
    init(repeatingRead: LumiKeychainReadResult) {
        self.readResults = []
        self.repeatingRead = repeatingRead
    }

    func read(service: String, account: String) -> LumiKeychainReadResult {
        lock.lock(); defer { lock.unlock() }
        let index = readCount
        readCount += 1
        if let repeatingRead { return repeatingRead }
        if index < readResults.count { return readResults[index] }
        return LumiKeychainReadResult(data: nil, status: errSecItemNotFound)
    }

    func write(_ data: Data, service: String, account: String) -> OSStatus {
        lock.lock(); defer { lock.unlock() }
        written.append((data, service, account))
        writeCount += 1
        return errSecSuccess
    }

    func delete(service: String, account: String) -> OSStatus {
        lock.lock(); defer { lock.unlock() }
        deleteCount += 1
        return errSecSuccess
    }
}

/// 捕获重试退避的毫秒序列，供断言指数退避节奏。
private final class BackoffCollector: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var recorded: [UInt64] = []

    func record(_ nanoseconds: UInt64) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(nanoseconds)
    }
}
