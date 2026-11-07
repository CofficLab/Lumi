import Foundation
import os

/// 开发者活动服务：节流记录事件、持久化、推断休息窗口、缓存快照与预测。
///
/// 由旧版 `Plugins/IdleTimePlugin/Sources/Services/IdleTimeService.swift` 迁移而来。
/// 差异：
/// - 不再依赖 KernelLumi / KitSuperLog；日志改用系统 `os.Logger`，不再 conform `SuperLog`；
/// - 存储目录由注入的 `IdleActivityStore` 决定（插件 onBoot 时用 StorageProviding
///   目录构造 store，不再依赖 `IdleTimeRuntimeBridge` 全局桥）；
/// - 快照刷新后经 `IdleTimeSnapshotChangeCenter` 广播，同时通过协议级
///   `addObserver(_:)` 对外发布 `IdleTimeProvidingEvent.snapshotChanged`，
///   消费方无需再依赖旁路 center。
public actor IdleTimeService: IdleTimeProviding {
    public static let shared = IdleTimeService()

    public static let idlePredictionConfidenceThreshold = 0.70

    private static let logger = Logger(subsystem: "com.coffic.lumi.provider-idle-time", category: "IdleTimeService")

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
            Self.logger.error("IdleTimeService failed to record activity: \(error.localizedDescription)")
        }
    }

    /// 获取当前推断快照。仅供视图模型（如 AppIdleTimeVM）调用。
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

    /// 注册开发者活动状态观察者。
    ///
    /// 快照刷新后回调收到 `.snapshotChanged`。底层复用
    /// `IdleTimeSnapshotChangeCenter`（lock 保护的全局中心），因此可
    /// nonisolated 安全调用；回调为 `@Sendable`，可能在任意线程执行。
    public nonisolated func addObserver(
        _ callback: @escaping @Sendable (IdleTimeProvidingEvent) -> Void
    ) -> any IdleTimeProvidingObserverHandle {
        let handle = IdleTimeSnapshotChangeCenter.shared.addObserver {
            callback(.snapshotChanged)
        }
        return IdleTimeServiceObserverHandle(cancel: handle.cancel)
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
            IdleTimeSnapshotChangeCenter.shared.notify()
        } catch {
            Self.logger.error("IdleTimeService failed to refresh snapshot: \(error.localizedDescription)")
        }
    }

    private func prune(now: Date) async throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -35, to: now) ?? now.addingTimeInterval(-35 * 24 * 60 * 60)
        try await store.prune(before: cutoff)
    }
}

/// `IdleTimeService.addObserver` 返回的句柄：包装底层
/// `IdleTimeSnapshotChangeHandle` 的取消闭包。
private final class IdleTimeServiceObserverHandle: IdleTimeProvidingObserverHandle, @unchecked Sendable {
    private var cancelAction: (() -> Void)?

    fileprivate init(cancel: @escaping () -> Void) {
        self.cancelAction = cancel
    }

    public func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
