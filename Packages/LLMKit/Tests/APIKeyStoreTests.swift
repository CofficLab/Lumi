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

    func testExpectedKeyRetriesAndBecomesUnavailableInsteadOfMissing() throws {
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
        XCTAssertEqual(backend.readCount, 4)
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

    func testRemoveClearsMemoryCache() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecSuccess, data: Data("secret".utf8)),
            KeychainResult(status: errSecItemNotFound, data: nil),
        ])
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        try fixture.store.setReportingErrors("secret", forKey: "account")
        try fixture.store.removeReportingErrors(forKey: "account")

        XCTAssertThrowsError(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account")
        ) { error in
            XCTAssertNil((error as? APIKeyStoreError)?.cachedValue)
        }
    }

    func testOverwritingValueRefreshesMemoryCache() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecSuccess, data: Data("old".utf8)),
            KeychainResult(status: errSecSuccess, data: Data("new".utf8)),
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

    func testSettingEmptyValueClearsMemoryCache() throws {
        let backend = SequenceKeychainBackend([
            KeychainResult(status: errSecSuccess, data: Data("secret".utf8)),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
            KeychainResult(status: errSecItemNotFound, data: nil),
        ])
        let fixture = makeStore(backend: backend)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        try fixture.store.setReportingErrors("secret", forKey: "account")
        try fixture.store.setReportingErrors("   ", forKey: "account")

        XCTAssertThrowsError(
            try fixture.store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: "account")
        ) { error in
            XCTAssertNil((error as? APIKeyStoreError)?.cachedValue)
        }
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