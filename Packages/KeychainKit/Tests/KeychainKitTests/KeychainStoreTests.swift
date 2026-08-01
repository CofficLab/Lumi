import Security
import XCTest
@testable import KeychainKit

final class KeychainStoreTests: XCTestCase {
    func testReportingReadReturnsValue() throws {
        let backend = StubKeychainBackend(
            readResult: KeychainResult(status: errSecSuccess, data: Data("secret".utf8))
        )
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        XCTAssertEqual(try store.stringReportingErrors(forKey: "account"), "secret")
        XCTAssertEqual(backend.readCount, 1)
    }

    func testReportingReadReturnsNilOnlyForMissingItem() throws {
        let backend = StubKeychainBackend(
            readResult: KeychainResult(status: errSecItemNotFound, data: nil)
        )
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        XCTAssertNil(try store.stringReportingErrors(forKey: "account"))
        XCTAssertEqual(backend.readCount, 1)
    }

    func testReportingReadThrowsUnexpectedOSStatus() {
        let backend = StubKeychainBackend(
            readResult: KeychainResult(status: errSecAuthFailed, data: nil)
        )
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        XCTAssertThrowsError(try store.stringReportingErrors(forKey: "account")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .readFailed(errSecAuthFailed))
            XCTAssertTrue(error.localizedDescription.contains("OSStatus \(errSecAuthFailed)"))
        }
        XCTAssertEqual(backend.readCount, 1)
    }

    func testReportingReadRetriesTransientFailureThenThrowsStatus() {
        let backend = StubKeychainBackend(
            readResult: KeychainResult(status: errSecNotAvailable, data: nil)
        )
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        XCTAssertThrowsError(try store.stringReportingErrors(forKey: "account")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .readFailed(errSecNotAvailable))
        }
        XCTAssertEqual(backend.readCount, KeychainStore.maxTransientAttempts)
    }

    func testReportingReadRejectsInvalidUTF8() {
        let backend = StubKeychainBackend(
            readResult: KeychainResult(status: errSecSuccess, data: Data([0xFF]))
        )
        let store = KeychainStore(service: "test", backend: backend, sleeper: { _ in })

        XCTAssertThrowsError(try store.stringReportingErrors(forKey: "account")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .invalidStringData)
        }
    }
}

private final class StubKeychainBackend: KeychainBackend, @unchecked Sendable {
    private let lock = NSLock()
    private let readResult: KeychainResult
    private var storedReadCount = 0

    init(readResult: KeychainResult) {
        self.readResult = readResult
    }

    var readCount: Int {
        lock.withLock { storedReadCount }
    }

    func read(service: String, account: String) -> KeychainResult {
        lock.withLock {
            storedReadCount += 1
        }
        return readResult
    }

    func write(_ data: Data, service: String, account: String) -> KeychainResult {
        KeychainResult(status: errSecSuccess, data: data)
    }

    func delete(service: String, account: String) -> KeychainResult {
        KeychainResult(status: errSecSuccess, data: nil)
    }
}
