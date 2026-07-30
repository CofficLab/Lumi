import Combine
import Foundation
import SuperLogKit
import os

/// Service for monitoring Lumi app's own memory usage (not system-wide).
@MainActor
public final class LumiMemoryService: ObservableObject, SuperLog {
    public static let shared = LumiMemoryService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.lumi-memory")
    nonisolated(unsafe) static var verbose: Bool = true
    nonisolated public static let emoji = "💾"

    // MARK: - Published Properties

    /// Current Lumi memory usage in bytes
    @Published public var currentMemoryBytes: UInt64 = 0

    /// Current Lumi memory usage as formatted string (e.g., "512 MB")
    @Published public var currentMemoryFormatted: String = "0 MB"

    /// Memory footprint history for charting (high-resolution, 1s sampling)
    @Published public var history: [LumiMemoryDataPoint] = []

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var subscribersCount = 0
    private let maxHistoryPoints = 3600  // Keep 1 hour of 1s samples

    // MARK: - Initialization

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose {
                Self.logger.info("\(Self.emoji) 开始 Lumi 内存监控")
            }

            updateMemoryUsage()

            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateMemoryUsage()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            monitoringTimer = timer
        }
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose {
                Self.logger.info("\(Self.emoji) 停止 Lumi 内存监控")
            }

            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }

    /// Get memory data for a specific time range
    public func getData(for range: LumiMemoryTimeRange) -> [LumiMemoryDataPoint] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - range.duration
        return history.filter { $0.timestamp >= cutoff }
    }

    /// Clear all history data
    public func clearHistory() {
        history.removeAll()
    }

    // MARK: - Private Methods

    private func updateMemoryUsage() {
        let memoryBytes = Self.getCurrentProcessMemory()
        let formatted = Self.formatMemory(memoryBytes)

        currentMemoryBytes = memoryBytes
        currentMemoryFormatted = formatted

        // Record data point
        let point = LumiMemoryDataPoint(
            timestamp: Date().timeIntervalSince1970,
            memoryBytes: memoryBytes
        )
        history.append(point)

        // Trim history if needed
        if history.count > maxHistoryPoints {
            history.removeFirst(history.count - maxHistoryPoints)
        }
    }

    // MARK: - Static Helpers

    /// Get current process memory usage using mach_task_basic_info
    private nonisolated static func getCurrentProcessMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }

    /// Format memory bytes to human-readable string
    private nonisolated static func formatMemory(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

// MARK: - Supporting Types

/// Time range for memory history queries
public enum LumiMemoryTimeRange: String, CaseIterable, Identifiable {
    case minute5 = "5m"
    case minute15 = "15m"
    case hour1 = "1h"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .minute5: return "5m"
        case .minute15: return "15m"
        case .hour1: return "1h"
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .minute5: return 300
        case .minute15: return 900
        case .hour1: return 3600
        }
    }
}

/// A single memory data point for Lumi's own usage
public struct LumiMemoryDataPoint: Identifiable, Equatable, Sendable {
    public var id: TimeInterval { timestamp }
    public let timestamp: TimeInterval
    public let memoryBytes: UInt64

    public var memoryMB: Double {
        Double(memoryBytes) / (1024 * 1024)
    }
}
