import Foundation
import ProviderIdleTime
import SwiftUI

private final class AppIdleTimeTimerHolder: @unchecked Sendable {
    var timer: Timer?

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}

/// 休息窗口快照视图模型：订阅快照变化通知 + 周期性刷新。
///
/// 由旧版 `Plugins/IdleTimePlugin/Sources/ViewModels/AppIdleTimeVM.swift` 迁移而来，
/// 差异：不再默认依赖 `IdleTimeService.shared`，改为显式注入 provider。
@MainActor
public final class AppIdleTimeVM: ObservableObject {
    @Published public private(set) var restWindow: RestWindow?
    @Published public private(set) var confidenceLabel: IdleConfidenceLabel = .learning
    @Published public private(set) var isInRestWindow: Bool = false
    @Published public private(set) var activityScores: [Double] = []
    @Published public private(set) var snapshot: IdleInferenceSnapshot?

    private var snapshotObserver: IdleTimeSnapshotObserver?
    private nonisolated let refreshTimerHolder = AppIdleTimeTimerHolder()
    private var refreshTask: Task<Void, Never>?
    private let provider: (any IdleTimeProviding)?

    public init(provider: (any IdleTimeProviding)?) {
        self.provider = provider
        snapshotObserver = IdleTimeSnapshotObserver { [weak self] in
            self?.refreshFromService()
        }
        schedulePeriodicRefresh()
    }

    deinit {
        refreshTimerHolder.invalidate()
        refreshTask?.cancel()
    }

    private func schedulePeriodicRefresh() {
        guard refreshTimerHolder.timer == nil else { return }

        refreshFromService()

        refreshTimerHolder.timer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromService()
            }
        }
    }

    private func refreshFromService() {
        guard let provider, refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil }

            let snapshot = await provider.currentSnapshot()

            self.snapshot = snapshot
            self.restWindow = snapshot.restWindow
            self.activityScores = snapshot.bucketScores

            if let window = snapshot.restWindow {
                self.confidenceLabel = IdleConfidenceLabel.label(
                    for: window.confidence,
                    source: window.source
                )
                self.isInRestWindow = window.contains(Date())
                    && window.source != .defaultFallback
                    && window.confidence >= 0.70
            } else {
                self.confidenceLabel = .learning
                self.isInRestWindow = false
            }
        }
    }
}
