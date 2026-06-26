import Foundation

/// Serializes availability HTTP checks to respect provider concurrency limits.
actor AvailabilityScheduler {
    static let shared = AvailabilityScheduler()

    private let minimumInterval: Duration
    private var lastFinishedAt: ContinuousClock.Instant?
    private var serial: Task<Void, Never>?

    init(minimumInterval: Duration = .seconds(1)) {
        self.minimumInterval = minimumInterval
    }

    func run<T: Sendable>(_ operation: @escaping @Sendable () async -> T) async -> T {
        let priorSerial = serial
        let interval = minimumInterval

        let job = Task { () async -> T in
            await priorSerial?.value

            if let delay = await AvailabilityScheduler.shared.delayBeforeNextRequest(
                minimumInterval: interval
            ) {
                try? await Task.sleep(for: delay)
            }

            let value = await operation()
            await AvailabilityScheduler.shared.recordFinish()
            return value
        }

        serial = Task { _ = await job.value }
        return await job.value
    }

    private func delayBeforeNextRequest(minimumInterval: Duration) -> Duration? {
        guard let lastFinishedAt else { return nil }
        let elapsed = ContinuousClock.now - lastFinishedAt
        guard elapsed < minimumInterval else { return nil }
        return minimumInterval - elapsed
    }

    private func recordFinish() {
        lastFinishedAt = .now
    }
}
