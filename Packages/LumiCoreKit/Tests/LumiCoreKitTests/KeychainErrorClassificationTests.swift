import Foundation
import KeychainKit
import Security
import Testing

@Suite("KeychainErrorClassification", .serialized)
struct KeychainErrorClassificationTests {
    @Test func successWithDataClassifiedAsFound() {
        let data = Data("sk-test".utf8)
        let outcome = classifyKeychainResult(status: errSecSuccess, data: data)

        guard case .found(let stored) = outcome else {
            Issue.record("应为 .found，实际：\(outcome)")
            return
        }
        #expect(stored == data)
    }

    @Test func successWithNilDataClassifiedAsMissing() {
        let outcome = classifyKeychainResult(status: errSecSuccess, data: nil)
        guard case .missing = outcome else {
            Issue.record("应为 .missing，实际：\(outcome)")
            return
        }
    }

    @Test func itemNotFoundClassifiedAsMissing() {
        let outcome = classifyKeychainResult(status: errSecItemNotFound, data: nil)
        guard case .missing = outcome else {
            Issue.record("应为 .missing，实际：\(outcome)")
            return
        }
    }

    @Test func interactionNotAllowedClassifiedAsTransient() {
        let outcome = classifyKeychainResult(status: errSecInteractionNotAllowed, data: nil)
        guard case .transientFailure(let code) = outcome else {
            Issue.record("应为 .transientFailure，实际：\(outcome)")
            return
        }
        #expect(code == errSecInteractionNotAllowed)
    }

    @Test func notAvailableClassifiedAsTransient() {
        let outcome = classifyKeychainResult(status: errSecNotAvailable, data: nil)
        guard case .transientFailure(let code) = outcome else {
            Issue.record("应为 .transientFailure，实际：\(outcome)")
            return
        }
        #expect(code == errSecNotAvailable)
    }

    @Test func duplicateCallbackClassifiedAsTransient() {
        let outcome = classifyKeychainResult(status: errSecDuplicateCallback, data: nil)
        guard case .transientFailure(let code) = outcome else {
            Issue.record("应为 .transientFailure，实际：\(outcome)")
            return
        }
        #expect(code == errSecDuplicateCallback)
    }

    @Test func authFailedClassifiedAsUnexpected() {
        // 新实现只把 interactionNotAllowed / notAvailable / duplicateCallback 视为瞬时；
        // errSecAuthFailed 落入 .unexpected，需要用户介入而非自动重试。
        let outcome = classifyKeychainResult(status: errSecAuthFailed, data: nil)
        guard case .unexpected(let code) = outcome else {
            Issue.record("应为 .unexpected，实际：\(outcome)")
            return
        }
        #expect(code == errSecAuthFailed)
    }

    @Test func unknownStatusClassifiedAsUnexpected() {
        let unknown: OSStatus = -99999
        let outcome = classifyKeychainResult(status: unknown, data: nil)
        guard case .unexpected(let code) = outcome else {
            Issue.record("应为 .unexpected，实际：\(outcome)")
            return
        }
        #expect(code == unknown)
    }

    @Test func transientFailuresCarryOriginalStatus() {
        // 不同瞬时错误码应各自保留原值，便于诊断
        let interaction = classifyKeychainResult(status: errSecInteractionNotAllowed, data: nil)
        let notAvailable = classifyKeychainResult(status: errSecNotAvailable, data: nil)

        guard case .transientFailure(let code) = interaction else {
            Issue.record("errSecInteractionNotAllowed 应为 transientFailure")
            return
        }
        #expect(code == errSecInteractionNotAllowed)

        guard case .transientFailure(let code) = notAvailable else {
            Issue.record("errSecNotAvailable 应为 transientFailure")
            return
        }
        #expect(code == errSecNotAvailable)
    }
}
