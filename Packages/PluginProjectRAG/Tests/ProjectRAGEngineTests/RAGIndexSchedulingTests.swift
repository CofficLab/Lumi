import Foundation
import Testing
@testable import ProjectRAGEngine

@Suite struct RAGIndexSchedulingTests {
    @Test func selectsMissingIndexBeforeStaleIndex() {
        let now = Date(timeIntervalSince1970: 1_000)
        let candidates = [
            RAGIndexCandidate(projectPath: "/stale", lastIndexedAt: now, needsIndex: true),
            RAGIndexCandidate(projectPath: "/missing", lastIndexedAt: nil, needsIndex: true),
        ]

        let selected = RAGIndexCandidateSelector.select(
            candidates: candidates,
            currentProjectPath: nil,
            retryStates: [:],
            now: now
        )

        #expect(selected?.projectPath == "/missing")
    }

    @Test func neverSelectsCurrentProject() {
        let candidate = RAGIndexCandidate(projectPath: "/active", lastIndexedAt: nil, needsIndex: true)
        let selected = RAGIndexCandidateSelector.select(
            candidates: [candidate],
            currentProjectPath: "/active/",
            retryStates: [:],
            now: Date()
        )

        #expect(selected == nil)
    }

    @Test func failedProjectUsesExponentialBackoff() {
        var state = RAGIndexRetryState()
        let configuration = RAGIndexSchedulingConfiguration()
        let now = Date(timeIntervalSince1970: 1_000)

        state.recordFailure(at: now, configuration: configuration)
        #expect(state.failureCount == 1)
        #expect(state.nextEligibleAt == now.addingTimeInterval(60))

        #expect(!state.isEligible(at: now.addingTimeInterval(59.9)))
        #expect(state.isEligible(at: now.addingTimeInterval(60)))
    }

    @Test func selectorCanRepresentAProjectThatStillNeedsIndexing() {
        let candidate = RAGIndexCandidate(
            projectPath: "/needs-index",
            lastIndexedAt: Date(),
            needsIndex: true
        )
        let selected = RAGIndexCandidateSelector.select(
            candidates: [candidate],
            currentProjectPath: nil,
            retryStates: [:],
            now: Date()
        )

        #expect(selected?.projectPath == "/needs-index")
    }
}
