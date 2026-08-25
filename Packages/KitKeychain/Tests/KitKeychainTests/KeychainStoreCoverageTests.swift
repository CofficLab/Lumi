import Security
import XCTest
@testable import KitKeychain

final class KeychainStoreCoverageTests: XCTestCase {
    private var legacyKey: String!

    override func setUp() {
        super.setUp()
        legacyKey = "legacy-\(UUID().uuidString)"
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: legacyKey!)
        super.tearDown()
    }

    // MARK: - Retry backoff

    func testTransientRetryDelayDoublesExponentially() {
        XCTAssertEqual(KeychainStore.transientRetryDelayNanoseconds(for: 0), 50_000_000)
        XCTAssertEqual(KeychainStore.transientRetryDelayNanoseconds(for: 1), 100_000_000)
        XCTAssertEqual(KeychainStore.transientRetryDelayNanoseconds(for: 2), 200_000_000)
        XCTAssertEqual(KeychainStore.transientRetryDelayNanoseconds(for: 3), 400_000_000)
    }

    func testTransientFailureSleepsBetweenRetriesWithBackoff() {
        let backend = StubKeychainBackend(readResult: KeychainResult(status: errSecNotAvailable, data: nil))
        var delays: [UInt64] = []
        let store = KeychainStore(service: "test", backend: backend) { nanoseconds in
            delays.append(nanoseconds)
        }

        XCTAssertThrowsError(try store.stringReportingErrors(forKey: "account"))
        // maxTransientAttempts = 4，最后一次尝试前不再 sleep
        XCTAssertEqual(delays, [
            50_000_000, 100_000_000, 200_000_000
        ])
    }

    // MARK: - classifyKeychainResult

    func testClassifySuccessWithData() {
        guard case .found(let data) = classifyKeychainResult(status: errSecSuccess, data: Data("x".utf8)) else {
            return XCTFail("expected .found")
        }
        XCTAssertEqual(data, Data("x".utf8))
    }

    func testClassifySuccessWithoutDataIsUnexpected() {
        guard case .unexpected(let status) = classifyKeychainResult(status: errSecSuccess, data: nil) else {
            return XCTFail("expected .unexpected")
        }
        XCTAssertEqual(status, errSecSuccess)
    }

    func testClassifyMissing() {
        guard case .missing = classifyKeychainResult(status: errSecItemNotFound, data: nil) else {
            return XCTFail("expected .missing")
        }
    }

    func testClassifyTransientStatuses() {
        for status in [errSecInteractionNotAllowed, errSecNotAvailable, errSecDuplicateCallback] {
            guard case .transientFailure(let observed) = classifyKeychainResult(status: status, data: nil) else {
                return XCTFail("expected .transientFailure for \(status)")
            }
            XCTAssertEqual(observed, status)
        }
    }

    func testClassifyUnexpectedStatus() {
        guard case .unexpected(let status) = classifyKeychainResult(status: errSecAuthFailed, data: nil) else {
            return XCTFail("expected .unexpected")
        }
        XCTAssertEqual(status, errSecAuthFailed)
    }

    // MARK: - Empty-key guards

    func testEmptyKeyShortCircuitsAllOperations() throws {
        let backend = RecordingKeychainBackend()
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        XCTAssertNil(try store.stringReportingErrors(forKey: ""))
        XCTAssertNoThrow(try store.setReportingErrors("value", forKey: ""))
        XCTAssertNoThrow(try store.removeReportingErrors(forKey: ""))
        XCTAssertNil(try store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: ""))
        XCTAssertEqual(backend.readCount, 0)
        XCTAssertEqual(backend.writeCount, 0)
        XCTAssertEqual(backend.deleteCount, 0)
    }

    // MARK: - Write behavior

    func testWriteTrimsWhitespaceBeforeStoring() throws {
        let backend = RecordingKeychainBackend()
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        try store.setReportingErrors("  secret \n", forKey: "account")

        XCTAssertEqual(backend.writtenData, [Data("secret".utf8)])
    }

    func testWriteWhitespaceOnlyValueRemovesKey() throws {
        let backend = RecordingKeychainBackend()
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        try store.setReportingErrors("   \n ", forKey: "account")

        XCTAssertEqual(backend.deleteCount, 1)
        XCTAssertEqual(backend.writtenData, [])
    }

    func testRemoveThrowsDeleteFailure() {
        let backend = StubKeychainBackend(
            readResult: KeychainResult(status: errSecItemNotFound, data: nil),
            deleteResult: KeychainResult(status: errSecAuthFailed, data: nil)
        )
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        XCTAssertThrowsError(try store.removeReportingErrors(forKey: "account")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .deleteFailed(errSecAuthFailed))
            XCTAssertTrue(error.localizedDescription.contains("OSStatus \(errSecAuthFailed)"))
        }
    }

    // MARK: - Non-throwing wrappers swallow errors

    func testNonThrowingWrappersSwallowFailures() {
        let backend = StubKeychainBackend(
            readResult: KeychainResult(status: errSecAuthFailed, data: nil),
            writeResult: KeychainResult(status: errSecAuthFailed, data: nil),
            deleteResult: KeychainResult(status: errSecAuthFailed, data: nil)
        )
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        XCTAssertNil(store.string(forKey: "account"))
        store.set("secret", forKey: "account")
        store.remove(forKey: "account")
        XCTAssertNil(store.loadMigratingLegacyUserDefaults(forKey: "account"))
    }

    // MARK: - Observed status callback

    func testObservedStatusReceivesFinalStatus() throws {
        let backend = StubKeychainBackend(readResult: KeychainResult(status: errSecItemNotFound, data: nil))
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        var observed: [OSStatus] = []
        XCTAssertNil(try store.stringReportingErrors(forKey: "account") { status in
            observed.append(status)
        })
        XCTAssertEqual(observed, [errSecItemNotFound])
    }

    func testObservedStatusReceivesLastTransientStatus() {
        let backend = StubKeychainBackend(readResult: KeychainResult(status: errSecNotAvailable, data: nil))
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        var observed: [OSStatus] = []
        XCTAssertThrowsError(try store.stringReportingErrors(forKey: "account") { status in
            observed.append(status)
        })
        XCTAssertEqual(observed, [errSecNotAvailable])
    }

    // MARK: - Legacy UserDefaults migration

    func testLegacyMigrationMovesValueToKeychain() throws {
        UserDefaults.standard.set("legacy-token", forKey: legacyKey)
        let backend = RecordingKeychainBackend()
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        let value = try store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: legacyKey)

        XCTAssertEqual(value, "legacy-token")
        XCTAssertEqual(backend.writtenData, [Data("legacy-token".utf8)])
        XCTAssertNil(UserDefaults.standard.string(forKey: legacyKey))
    }

    func testKeychainValueWinsOverLegacy() throws {
        UserDefaults.standard.set("legacy-token", forKey: legacyKey)
        let backend = RecordingKeychainBackend(
            readData: Data("keychain-token".utf8)
        )
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        let value = try store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: legacyKey)

        XCTAssertEqual(value, "keychain-token")
        XCTAssertEqual(backend.writtenData, [])
        // 遗留值保持原样（不迁移也不清除）
        XCTAssertEqual(UserDefaults.standard.string(forKey: legacyKey), "legacy-token")
    }

    func testWhitespaceOnlyKeychainValueFallsBackToLegacy() throws {
        UserDefaults.standard.set("legacy-token", forKey: legacyKey)
        let backend = RecordingKeychainBackend(readData: Data("   ".utf8))
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        let value = try store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: legacyKey)

        XCTAssertEqual(value, "legacy-token")
        XCTAssertEqual(backend.writtenData, [Data("legacy-token".utf8)])
    }

    func testMigrationReturnsNilWhenBothSourcesEmpty() throws {
        let backend = RecordingKeychainBackend()
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        XCTAssertNil(try store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: legacyKey))
    }

    // MARK: - Error descriptions

    func testErrorDescriptions() {
        XCTAssertTrue(KeychainStoreError.writeFailed(errSecAuthFailed).localizedDescription.contains("Keychain write failed"))
        XCTAssertTrue(KeychainStoreError.deleteFailed(errSecAuthFailed).localizedDescription.contains("Keychain delete failed"))
        XCTAssertFalse(KeychainStoreError.missingDataForSuccessfulRead.localizedDescription.isEmpty)
        XCTAssertFalse(KeychainStoreError.invalidStringData.localizedDescription.isEmpty)
    }

    func testReadFailedDescriptionIncludesStatus() {
        let text = KeychainStoreError.readFailed(errSecItemNotFound).localizedDescription
        XCTAssertTrue(text.contains("Keychain read failed"))
        XCTAssertTrue(text.contains("\(errSecItemNotFound)"))
    }

    func testFailedDescriptionFallsBackForUnknownStatus() {
        // 极端 OSStatus 也要产出非空、含状态码的描述（未知状态由系统文案兜底）。
        let text = KeychainStoreError.writeFailed(OSStatus(999_999)).localizedDescription
        XCTAssertTrue(text.contains("Keychain write failed"))
        XCTAssertTrue(text.contains("999999"))
    }
}

/// 可记录调用的后端
private final class RecordingKeychainBackend: KeychainBackend, @unchecked Sendable {
    private let lock = NSLock()
    private let readData: Data?
    private var storedWrittenData: [Data] = []
    private var storedDeleteCount = 0
    private var storedWriteCount = 0
    private var storedReadCount = 0

    init(readData: Data? = nil) {
        self.readData = readData
    }

    var writtenData: [Data] { lock.withLock { storedWrittenData } }
    var deleteCount: Int { lock.withLock { storedDeleteCount } }
    var writeCount: Int { lock.withLock { storedWriteCount } }
    var readCount: Int { lock.withLock { storedReadCount } }

    func read(service: String, account: String) -> KeychainResult {
        lock.withLock { storedReadCount += 1 }
        if let readData {
            return KeychainResult(status: errSecSuccess, data: readData)
        }
        return KeychainResult(status: errSecItemNotFound, data: nil)
    }

    func write(_ data: Data, service: String, account: String) -> KeychainResult {
        lock.withLock {
            storedWriteCount += 1
            storedWrittenData.append(data)
        }
        return KeychainResult(status: errSecSuccess, data: data)
    }

    func delete(service: String, account: String) -> KeychainResult {
        lock.withLock { storedDeleteCount += 1 }
        return KeychainResult(status: errSecSuccess, data: nil)
    }
}
