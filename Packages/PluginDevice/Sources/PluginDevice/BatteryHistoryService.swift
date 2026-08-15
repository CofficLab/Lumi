import Combine
import Foundation
import os
import SuperLogKit

/// Battery power history service with high-resolution (5s) storage.
///
/// Records battery power draw/charge over time for trend visualization.
@MainActor
public final class BatteryHistoryService: ObservableObject, SuperLog {
    public static let shared = BatteryHistoryService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.battery-history")
    nonisolated public static let emoji = "📈"

    /// High resolution buffer (5s interval) — keep last 1 hour.
    @Published public var recentHistory: [BatteryDataPoint] = []

    private let maxRecentPoints = 720 // 1 hour / 5 seconds

    private var cancellables = Set<AnyCancellable>()

    package init() {}

    // MARK: - Public Methods

    public func startRecording() {
        guard cancellables.isEmpty else { return }

        BatteryService.shared.startMonitoring()
        BatteryService.shared.$watts
            .sink { [weak self] watts in
                self?.recordDataPoint(watts: watts)
            }
            .store(in: &cancellables)
    }

    public func stopRecording() {
        guard !cancellables.isEmpty else { return }

        cancellables.removeAll()
        BatteryService.shared.stopMonitoring()
    }

    public func getData(for range: BatteryTimeRange) -> [BatteryDataPoint] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - range.duration
        return recentHistory.filter { $0.timestamp >= cutoff }
    }

    // MARK: - Internal Methods

    func recordDataPoint(watts: Double) {
        let now = Date().timeIntervalSince1970
        let point = BatteryDataPoint(timestamp: now, watts: watts)

        recentHistory.append(point)
        if recentHistory.count > maxRecentPoints {
            recentHistory.removeFirst(recentHistory.count - maxRecentPoints)
        }
    }
}
