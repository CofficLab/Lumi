import KeychainKit
import Security
import XCTest
@testable import LLMKit

final class APIKeyStoreTests: XCTestCase {
    func testUnknownMissingKeyIsReportedImmediately() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecItemNotFound, data: nil),
        ])
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

        XCTAssertNil(try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account"))
        XCTAssertEqual(backend.readCount, 1)
    }

    /// "expected 但本进程无缓存"的纯诊断路径：用两个共享 UserDefaults 的
    /// store 实例模拟"重启后 Keychain 视图已陈旧"——store1 写入建立
    /// expected-configured 标记，store2 没有内存缓存，读到持续 missing 时
    /// 只能抛出带 statusTrace 的诊断错误。
    func testExpectedKeyRetriesAndBecomesUnavailableInsteadOfMissing() throws {
        let suiteName = "APIKeyStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let writer = APIKeyStore(
            store: KeychainStore(
                service: "test",
                backend: SequenceKeychainBackend([
                    KeychainResult(status: errSecSuccess, data: Data("secret".utf8)),
                ]),
                sleeper: { _ in }
            ),
            defaults: defaults,
            sleeper: { _ in }
        )
        try writer.setReportingErrors("secret", forKey: "account")

        let readerBackend = SequenceKeychainBackend(
            Array(repeating: KeychainResult(status: errSecItemNotFound, data: nil), count: 4)
        )
        let reader = APIKeyStore(
            store: KeychainStore(service: "test", backend: readerBackend, sleeper: { _ in }),
            defaults: defaults,
            sleeper: { _ in }
        )

        XCTAssertThrowsError(
            try reader.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account")
        ) { error in
            guard let storeError = error as? APIKeyStoreError else {
                XCTFail("Expected APIKeyStoreError, got \(error)")
                return
            }
            switch storeError {
            case .expectedItemMissing(
                let account,
                let attempts,
                let lastStatus,
                let statusTrace,
                let servedFromCache
            ):
                XCTAssertEqual(account, "account")
                XCTAssertEqual(attempts, 4)
                XCTAssertEqual(lastStatus, Int(errSecItemNotFound))
                XCTAssertEqual(statusTrace, Array(repeating: Int(errSecItemNotFound), count: 4))
                XCTAssertNil(servedFromCache)
            }
        }
        XCTAssertEqual(readerBackend.readCount, 4)
    }

    func testExpectedKeyRecoversDuringConfirmationReads() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecSuccess, data: Data("secret".utf8)),
        ])
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        try fixture.store.setReportingErrors("secret", forKey: "account")

        XCTAssertEqual(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account"),
            "secret"
        )
        XCTAssertEqual(backend.readCount, 3)
    }

    func testSuccessfulReadBootstrapsExpectedConfiguredState() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecSuccess, data: Data("secret".utf8)),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
        ])
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

        XCTAssertEqual(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account"),
            "secret"
        )
        XCTAssertThrowsError(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account")
        )
    }

    func testNonThrowingDisplayReadDoesNotRunMissingConfirmationLoop() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecItemNotFound, data: nil),
        ])
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        try fixture.store.setReportingErrors("secret", forKey: "account")

        XCTAssertNil(fixture.store.loadMigratingLegacyUserDefaults(forKey: "account"))
        XCTAssertEqual(backend.readCount, 1)
    }

    func testExpectedKeyFallsBackToMemoryCacheWhenKeychainStaysMissing() throws {
        let backend = SequenceKeychainBackend(
            Array(repeating: KeychainResult(status: errSecItemNotFound, data: nil), count: 4)
        )
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        try fixture.store.setReportingErrors("secret", forKey: "account")

        XCTAssertThrowsError(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account")
        ) { error in
            guard let storeError = error as? APIKeyStoreError else {
                XCTFail("Expected APIKeyStoreError, got \(error)")
                return
            }
            XCTAssertEqual(storeError.cachedValue, "secret")
            if case let .expectedItemMissing(_, _, lastStatus, _, servedFromCache) = storeError {
                XCTAssertEqual(lastStatus, Int(errSecItemNotFound))
                XCTAssertEqual(servedFromCache, "secret")
            }
        }
        XCTAssertEqual(backend.readCount, 4)
    }

    /// remove 后 flag 与缓存都被清除，Keychain 再报 missing 时按"未配置"
    /// 返回 nil，而不是抛出 expectedItemMissing 或泄漏旧缓存值。
    func testRemoveClearsMemoryCache() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecItemNotFound, data: nil),
        ])
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        try fixture.store.setReportingErrors("secret", forKey: "account")
        try fixture.store.removeReportingErrors(forKey: "account")

        XCTAssertNil(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account")
        )
        XCTAssertEqual(backend.readCount, 1)
    }

    /// set 覆写后缓存应立即反映新值：Keychain 随后持续 missing 时，
    /// 兜底返回的是新值而不是旧的。
    func testOverwritingValueRefreshesMemoryCache() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecSuccess, data: Data("old".utf8)),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
        ])
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        try fixture.store.setReportingErrors("old", forKey: "account")
        XCTAssertEqual(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account"),
            "old"
        )
        try fixture.store.setReportingErrors("new", forKey: "account")
        XCTAssertThrowsError(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account")
        ) { error in
            XCTAssertEqual((error as? APIKeyStoreError)?.cachedValue, "new")
        }
    }

    /// 写入空串等价于 remove：flag 与缓存被清除，后续按"未配置"处理。
    func testSettingEmptyValueClearsMemoryCache() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecItemNotFound, data: nil),
        ])
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        try fixture.store.setReportingErrors("secret", forKey: "account")
        try fixture.store.setReportingErrors("   ", forKey: "account")

        XCTAssertNil(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account")
        )
    }

    func testUnexpectedOSStatusIsReportedInDiagnostics() throws {
        let backend = SequenceKeychainBackend(
            Array(repeating: KeychainResult(status: errSecNotAvailable, data: nil), count: 4)
        )
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        try fixture.store.setReportingErrors("secret", forKey: "account")

        XCTAssertThrowsError(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account")
        ) { error in
            guard let storeError = error as? APIKeyStoreError else {
                XCTFail("Expected APIKeyStoreError, got \(error)")
                return
            }
            if case let .expectedItemMissing(_, _, lastStatus, statusTrace, _) = storeError {
                XCTAssertEqual(lastStatus, Int(errSecNotAvailable))
                XCTAssertEqual(statusTrace, Array(repeating: Int(errSecNotAvailable), count: 4))
            }
        }
    }

    private func makeStore(backend: SequenceKeychainBackend) -> (
        store: APIKeyStore,
        defaults: UserDefaults,
        suiteName: String
    ) {
        let suiteName = "APIKeyStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let keychain = KeychainStore(service: "test", backend: backend, sleeper: { _ in })
        return (
            APIKeyStore(store: keychain, defaults: defaults, sleeper: { _ in }),
            defaults,
            suiteName
        )
    }
}

private final class SequenceKeychainBackend: KeychainBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [KeychainResult]
    private var storedReadCount = 0

    init(_ results: [KeychainResult]) {
        self.results = results
    }

    var readCount: Int {
        lock.withLock { storedReadCount }
    }

    func read(service: String, account: String) -> KeychainResult {
        lock.withLock {
            storedReadCount += 1
            if results.count > 1 {
                return results.removeFirst()
            }
            return results[0]
        }
    }

    func write(_ data: Data, service: String, account: String) -> KeychainResult {
        KeychainResult(status: errSecSuccess, data: data)
    }

    func delete(service: String, account: String) -> KeychainResult {
        KeychainResult(status: errSecSuccess, data: nil)
    }
}