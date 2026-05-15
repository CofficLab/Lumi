import Foundation

extension Notification.Name {
    static let idleTimeSnapshotDidChange = Notification.Name("IdleTimeSnapshotDidChange")
}

actor IdleTimeService {
    static let shared = IdleTimeService()

    private let store: IdleActivityStore
    private let inferencer: RestWindowInferencer
    private var lastRecordedAtByKind: [IdleActivityKind: Date] = [:]
    private var lastInferenceAt: Date?
    private var cachedSnapshot: IdleInferenceSnapshot?

    init(
        store: IdleActivityStore = .shared,
        inferencer: RestWindowInferencer = RestWindowInferencer()
    ) {
        self.store = store
        self.inferencer = inferencer
    }

    func record(_ kind: IdleActivityKind, at date: Date = Date()) async {
        if let lastRecordedAt = lastRecordedAtByKind[kind],
           date.timeIntervalSince(lastRecordedAt) < kind.throttleInterval {
            return
        }

        lastRecordedAtByKind[kind] = date
        let event = IdleActivityEvent(timestamp: date, kind: kind)

        do {
            try await store.append(event)
            try await prune(now: date)
            await refreshSnapshotIfNeeded(now: date, force: false)
        } catch {
            AppLogger.core.error("IdleTimeService failed to record activity: \(error.localizedDescription)")
        }
    }

    func currentSnapshot(for date: Date = Date()) async -> IdleInferenceSnapshot {
        if let cachedSnapshot,
           date.timeIntervalSince(cachedSnapshot.restWindow?.generatedAt ?? .distantPast) < 6 * 60 * 60 {
            return cachedSnapshot
        }

        if let stored = try? await store.loadSnapshot(),
           date.timeIntervalSince(stored.restWindow?.generatedAt ?? .distantPast) < 6 * 60 * 60 {
            cachedSnapshot = stored
            return stored
        }

        await refreshSnapshotIfNeeded(now: date, force: true)
        if let cachedSnapshot {
            return cachedSnapshot
        }

        return inferencer.infer(events: [], now: date)
    }

    func inferredRestWindow(for date: Date = Date()) async -> RestWindow? {
        await currentSnapshot(for: date).restWindow
    }

    func isInLikelyRestWindow(
        at date: Date = Date(),
        minimumConfidence: Double = 0.70
    ) async -> Bool {
        guard let window = await inferredRestWindow(for: date),
              window.source != .defaultFallback,
              window.confidence >= minimumConfidence else {
            return false
        }
        return window.contains(date)
    }

    private func refreshSnapshotIfNeeded(now: Date, force: Bool) async {
        if !force,
           let lastInferenceAt,
           now.timeIntervalSince(lastInferenceAt) < 10 * 60 {
            return
        }

        let cutoff = Calendar.current.date(byAdding: .day, value: -35, to: now) ?? now.addingTimeInterval(-35 * 24 * 60 * 60)

        do {
            let events = try await store.loadRecentEvents(since: cutoff)
            let snapshot = inferencer.infer(events: events, now: now)
            try await store.saveSnapshot(snapshot)
            cachedSnapshot = snapshot
            lastInferenceAt = now
            NotificationCenter.default.post(name: .idleTimeSnapshotDidChange, object: nil)
        } catch {
            AppLogger.core.error("IdleTimeService failed to refresh snapshot: \(error.localizedDescription)")
        }
    }

    private func prune(now: Date) async throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -35, to: now) ?? now.addingTimeInterval(-35 * 24 * 60 * 60)
        try await store.prune(before: cutoff)
    }
}
