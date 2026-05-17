import Foundation

actor HotPreviewBuildCoordinator {
    enum Result: Sendable {
        case built
        case reused
        case joined
    }

    private struct InFlightKey: Hashable {
        let strategy: LumiPreviewFacade.BuildStrategy
        let fingerprint: String
    }

    private var fingerprints: [LumiPreviewFacade.BuildStrategy: String] = [:]
    private var inFlightBuilds: [InFlightKey: Task<Void, Error>] = [:]

    func buildIfNeeded(
        strategy: LumiPreviewFacade.BuildStrategy,
        fingerprint: String?,
        operation: @escaping @Sendable () async throws -> Void
    ) async throws -> Result {
        guard let fingerprint else {
            try await operation()
            return .built
        }

        if fingerprints[strategy] == fingerprint {
            return .reused
        }

        let key = InFlightKey(strategy: strategy, fingerprint: fingerprint)
        if let build = inFlightBuilds[key] {
            try await build.value
            fingerprints[strategy] = fingerprint
            return .joined
        }

        let build = Task {
            try await operation()
        }
        inFlightBuilds[key] = build

        do {
            try await build.value
        } catch {
            inFlightBuilds[key] = nil
            throw error
        }

        inFlightBuilds[key] = nil
        fingerprints[strategy] = fingerprint
        return .built
    }
}
