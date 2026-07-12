import Foundation
import Security
@testable import LumiCoreKit
import Testing

@Suite("KeychainErrorClassification", .serialized)
struct KeychainErrorClassificationTests {
    @Test func successWithDataClassifiedAsFound() {
        let data = Data("sk-test".utf8)
        let outcome = classifyKeychainReadResult(status: errSecSuccess, data: data)

        #expect(outcome == .found(data))
    }

    @Test func successWithNilDataClassifiedAsMissing() {
        #expect(classifyKeychainReadResult(status: errSecSuccess, data: nil) == .missing)
    }

    @Test func itemNotFoundClassifiedAsMissing() {
        #expect(classifyKeychainReadResult(status: errSecItemNotFound, data: nil) == .missing)
    }

    @Test func interactionNotAllowedClassifiedAsTransient() {
        let outcome = classifyKeychainReadResult(status: errSecInteractionNotAllowed, data: nil)
        #expect(outcome == .transientFailure(errSecInteractionNotAllowed))
    }

    @Test func authFailedClassifiedAsTransient() {
        let outcome = classifyKeychainReadResult(status: errSecAuthFailed, data: nil)
        #expect(outcome == .transientFailure(errSecAuthFailed))
    }

    @Test func interactionRequiredClassifiedAsTransient() {
        let outcome = classifyKeychainReadResult(status: errSecInteractionRequired, data: nil)
        #expect(outcome == .transientFailure(errSecInteractionRequired))
    }

    @Test func dataNotAvailableClassifiedAsTransient() {
        let outcome = classifyKeychainReadResult(status: errSecDataNotAvailable, data: nil)
        #expect(outcome == .transientFailure(errSecDataNotAvailable))
    }

    @Test func unknownStatusClassifiedAsUnexpected() {
        let unknown: OSStatus = -99999
        #expect(classifyKeychainReadResult(status: unknown, data: nil) == .unexpected(unknown))
    }

    @Test func transientFailuresCarryOriginalStatus() {
        // 不同瞬时错误码应各自保留原值，便于诊断
        let interaction = classifyKeychainReadResult(status: errSecInteractionNotAllowed, data: nil)
        let auth = classifyKeychainReadResult(status: errSecAuthFailed, data: nil)

        if case .transientFailure(let code) = interaction { #expect(code == errSecInteractionNotAllowed) }
        else { Issue.record("应为 transientFailure") }

        if case .transientFailure(let code) = auth { #expect(code == errSecAuthFailed) }
        else { Issue.record("应为 transientFailure") }
    }
}
