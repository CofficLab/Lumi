import Foundation

struct RAGIndexSchedulingConfiguration: Sendable, Equatable {
    var idlePredictionDuration: TimeInterval = 10 * 60
    var schedulerPollInterval: TimeInterval = 60
    var retryBaseDelay: TimeInterval = 60
    var retryMaxDelay: TimeInterval = 30 * 60
    var maxConsecutiveFailures = 5

    func retryDelay(for failureCount: Int) -> TimeInterval {
        guard failureCount > 0 else { return 0 }
        let exponent = min(failureCount - 1, 10)
        return min(retryMaxDelay, retryBaseDelay * pow(2, Double(exponent)))
    }
}

struct RAGIndexCandidate: Sendable, Equatable {
    let projectPath: String
    let lastIndexedAt: Date?
    let needsIndex: Bool

    var priority: (Int, Date, String) {
        (
            needsIndex ? 0 : 1,
            lastIndexedAt ?? .distantPast,
            projectPath
        )
    }
}

struct RAGIndexRetryState: Codable, Sendable, Equatable {
    var failureCount: Int = 0
    var nextEligibleAt: Date = .distantPast

    func isEligible(at date: Date) -> Bool {
        date >= nextEligibleAt
    }

    mutating func recordFailure(
        at date: Date,
        configuration: RAGIndexSchedulingConfiguration
    ) {
        failureCount = min(failureCount + 1, configuration.maxConsecutiveFailures)
        nextEligibleAt = date.addingTimeInterval(configuration.retryDelay(for: failureCount))
    }

    mutating func recordSuccess() {
        failureCount = 0
        nextEligibleAt = .distantPast
    }
}

struct RAGIndexSliceExpired: Error, Sendable {}

enum RAGIndexCandidateSelector {
    static func select(
        candidates: [RAGIndexCandidate],
        currentProjectPath: String?,
        retryStates: [String: RAGIndexRetryState],
        now: Date
    ) -> RAGIndexCandidate? {
        let current = currentProjectPath.map(RAGPathUtils.normalizeProjectPath)
        return candidates
            .filter { candidate in
                candidate.projectPath != current
                    && (retryStates[candidate.projectPath]?.isEligible(at: now) ?? true)
            }
            .sorted { $0.priority < $1.priority }
            .first
    }
}
