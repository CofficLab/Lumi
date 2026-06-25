import Testing
import Foundation
@testable import GitHubPlugin

/// Unit tests for `GitHubToolArgumentNormalizer` — pure argument coercion/clamping.
@Suite struct GitHubToolArgumentNormalizerTests {

    // MARK: - integer

    @Test func integerAcceptsInt() {
        #expect(GitHubToolArgumentNormalizer.integer(5 as Any?) == 5)
    }

    @Test func integerAcceptsDouble() {
        #expect(GitHubToolArgumentNormalizer.integer(5.0 as Any?) == 5)
        #expect(GitHubToolArgumentNormalizer.integer(5.9 as Any?) == 5)
    }

    @Test func integerAcceptsNumericString() {
        #expect(GitHubToolArgumentNormalizer.integer("42" as Any?) == 42)
    }

    @Test func integerRejectsGarbage() {
        #expect(GitHubToolArgumentNormalizer.integer("abc" as Any?) == nil)
        #expect(GitHubToolArgumentNormalizer.integer(nil) == nil)
    }

    // MARK: - issueNumber

    @Test func issueNumberAcceptsPositive() {
        #expect(GitHubToolArgumentNormalizer.issueNumber(1 as Any?) == 1)
        #expect(GitHubToolArgumentNormalizer.issueNumber(12345 as Any?) == 12345)
    }

    @Test func issueNumberRejectsBelowMin() {
        #expect(GitHubToolArgumentNormalizer.issueNumber(0 as Any?) == nil)
        #expect(GitHubToolArgumentNormalizer.issueNumber(-5 as Any?) == nil)
    }

    @Test func issueNumberRejectsInvalid() {
        #expect(GitHubToolArgumentNormalizer.issueNumber("x" as Any?) == nil)
        #expect(GitHubToolArgumentNormalizer.issueNumber(nil) == nil)
    }

    // MARK: - nonNegativeInteger

    @Test func nonNegativeClampsBelowZero() {
        #expect(GitHubToolArgumentNormalizer.nonNegativeInteger(-3 as Any?) == 0)
    }

    @Test func nonNegativeKeepsPositive() {
        #expect(GitHubToolArgumentNormalizer.nonNegativeInteger(7 as Any?) == 7)
    }

    @Test func nonNegativeDefaultsToZeroForInvalid() {
        #expect(GitHubToolArgumentNormalizer.nonNegativeInteger(nil) == 0)
        #expect(GitHubToolArgumentNormalizer.nonNegativeInteger("x" as Any?) == 0)
    }

    // MARK: - page

    @Test func pageClampsToMin() {
        #expect(GitHubToolArgumentNormalizer.page(0 as Any?) == 1)
        #expect(GitHubToolArgumentNormalizer.page(-1 as Any?) == 1)
    }

    @Test func pageAcceptsValid() {
        #expect(GitHubToolArgumentNormalizer.page(3 as Any?) == 3)
    }

    @Test func pageDefaultsToMinForInvalid() {
        #expect(GitHubToolArgumentNormalizer.page(nil) == 1)
    }

    // MARK: - perPage

    @Test func perPageClampsToRange() {
        #expect(GitHubToolArgumentNormalizer.perPage(0 as Any?) == 1)
        #expect(GitHubToolArgumentNormalizer.perPage(500 as Any?) == 100)
    }

    @Test func perPageAcceptsInRange() {
        #expect(GitHubToolArgumentNormalizer.perPage(50 as Any?) == 50)
    }

    @Test func perPageDefaultsToTenForInvalid() {
        #expect(GitHubToolArgumentNormalizer.perPage(nil) == 10)
    }

    @Test func perPageAcceptsStringInput() {
        #expect(GitHubToolArgumentNormalizer.perPage("25" as Any?) == 25)
    }
}
