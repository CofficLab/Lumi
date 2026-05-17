import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("HotPreviewBuildCoordinator")
struct HotPreviewBuildCoordinatorTests {
    private let strategy = LumiPreviewFacade.BuildStrategy.spm(
        packageDirectory: URL(fileURLWithPath: "/tmp/PreviewPkg"),
        targetName: "App"
    )

    @Test("C.1 reuses build when strategy and fingerprint are unchanged")
    func reusesBuildForUnchangedFingerprint() async throws {
        let coordinator = HotPreviewBuildCoordinator()
        let counter = Counter()

        let first = try await coordinator.buildIfNeeded(strategy: strategy, fingerprint: "fp-1") {
            await counter.increment()
        }
        let second = try await coordinator.buildIfNeeded(strategy: strategy, fingerprint: "fp-1") {
            await counter.increment()
        }

        #expect(first == .built)
        #expect(second == .reused)
        #expect(await counter.value == 1)
    }

    @Test("C.2 builds every time when fingerprint is nil")
    func buildsEveryTimeWithoutFingerprint() async throws {
        let coordinator = HotPreviewBuildCoordinator()
        let counter = Counter()

        let first = try await coordinator.buildIfNeeded(strategy: strategy, fingerprint: nil) {
            await counter.increment()
        }
        let second = try await coordinator.buildIfNeeded(strategy: strategy, fingerprint: nil) {
            await counter.increment()
        }

        #expect(first == .built)
        #expect(second == .built)
        #expect(await counter.value == 2)
    }

    @Test("C.3 joins concurrent builds for the same key")
    func joinsConcurrentBuilds() async throws {
        let coordinator = HotPreviewBuildCoordinator()
        let counter = Counter()

        async let first = coordinator.buildIfNeeded(strategy: strategy, fingerprint: "fp-join") {
            try await Task.sleep(nanoseconds: 100_000_000)
            await counter.increment()
        }
        async let second = coordinator.buildIfNeeded(strategy: strategy, fingerprint: "fp-join") {
            await counter.increment()
        }

        let firstResult = try await first
        let secondResult = try await second

        let outcomes = Set([firstResult, secondResult])
        #expect(outcomes == [.built, .joined])
        #expect(await counter.value == 1)
    }

    @Test("C.4 clears in-flight build after failure and allows retry")
    func retriesAfterFailure() async throws {
        let coordinator = HotPreviewBuildCoordinator()
        let counter = Counter()

        do {
            _ = try await coordinator.buildIfNeeded(strategy: strategy, fingerprint: "fp-fail") {
                await counter.increment()
                throw TestFailure.expected
            }
        } catch TestFailure.expected {
        }

        let retry = try await coordinator.buildIfNeeded(strategy: strategy, fingerprint: "fp-fail") {
            await counter.increment()
        }

        #expect(retry == .built)
        #expect(await counter.value == 2)
    }
}

private actor Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private enum TestFailure: Error {
    case expected
}
