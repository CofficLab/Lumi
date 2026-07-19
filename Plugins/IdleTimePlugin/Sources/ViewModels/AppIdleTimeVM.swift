import Combine
import Foundation
import LumiKernel
import SwiftUI

private final class AppIdleTimeTimerHolder: @unchecked Sendable {
    var timer: Timer?

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
public final class AppIdleTimeVM: ObservableObject {
    @Published public private(set) var restWindow: RestWindow?
    @Published public private(set) var confidenceLabel: IdleConfidenceLabel = .learning
    @Published public private(set) var isInRestWindow: Bool = false
    @Published public private(set) var activityScores: [Double] = []
    @Published public private(set) var snapshot: IdleInferenceSnapshot?

    private var cancellables = Set<AnyCancellable>()
    private nonisolated let refreshTimerHolder = AppIdleTimeTimerHolder()
    private var refreshTask: Task<Void, Never>?

    public init() {
        subscribeToSnapshotChanges()
        schedulePeriodicRefresh()
    }

    deinit {
        refreshTimerHolder.invalidate()
        refreshTask?.cancel()
    }

    private func subscribeToSnapshotChanges() {
        NotificationCenter.default.publisher(for: .idleTimeSnapshotDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshFromService()
            }
            .store(in: &cancellables)
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
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil }

            let snapshot = await IdleTimeService.shared.currentSnapshot()

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
