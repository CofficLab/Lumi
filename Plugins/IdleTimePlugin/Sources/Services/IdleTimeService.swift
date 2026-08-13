import Foundation
import KernelLumi
import SuperLogKit

public actor IdleTimeService: SuperLog, IdleTimeProviding {
    public static let shared = IdleTimeService()

    public static let idlePredictionConfidenceThreshold = 0.70

    private let store: IdleActivityStore
    private let inferencer: RestWindowInferencer
    private var lastRecordedAtByKind: [IdleActivityKind: Date] = [:]
    private var lastInferenceAt: Date?
    private var cachedSnapshot: IdleInferenceSnapshot?

    public init(
        store: IdleActivityStore = .shared,
        inferencer: RestWindowInferencer = RestWindowInferencer()
    ) {
        self.store = store
        self.inferencer = inferencer
    }

    public func record(_ kind: IdleActivityKind, at date: Date = Date()) async {
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
            MagicLogger.error("IdleTimeService failed to record activity: \(error.localizedDescription)")
        }
    }

    /// 获取当前推断快照。仅供 `AppIdleTimeVM` 调用。
    public func currentSnapshot(for date: Date = Date()) async -> IdleInferenceSnapshot {
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

    public func idlePrediction(
        for duration: TimeInterval = 10 * 60,
        at date: Date = Date()
    ) async -> IdlePrediction {
        let snapshot = await currentSnapshot(for: date)
        let window = snapshot.restWindow
        let confidence = window?.confidence ?? 0
        let isLikelyIdle = duration > 0
            && window?.source != .defaultFallback
            && confidence >= Self.idlePredictionConfidenceThreshold
            && window?.covers(startingAt: date, duration: duration) == true

        return IdlePrediction(
            checkedAt: date,
            duration: duration,
            isLikelyIdle: isLikelyIdle,
            confidence: confidence,
            restWindow: window
        )
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
            await MainActor.run {
                NotificationCenter.default.post(name: .idleTimeSnapshotDidChange, object: nil)
            }
        } catch {
            MagicLogger.error("IdleTimeService failed to refresh snapshot: \(error.localizedDescription)")
        }
    }

    private func prune(now: Date) async throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -35, to: now) ?? now.addingTimeInterval(-35 * 24 * 60 * 60)
        try await store.prune(before: cutoff)
    }
}
