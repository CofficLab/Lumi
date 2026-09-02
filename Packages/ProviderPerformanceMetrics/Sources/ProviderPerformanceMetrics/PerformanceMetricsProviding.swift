import Foundation

/// A monotonic trace started on a user-facing hot path.
///
/// The trace contains only identifiers and timing metadata. It deliberately
/// does not carry message text, attachment data, or any other user content.
public struct PerformanceTrace: Hashable, Sendable {
    public let id: UUID
    public let operation: String

    let startedAtNanoseconds: UInt64
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        operation: String,
        startedAtNanoseconds: UInt64,
        metadata: [String: String]
    ) {
        self.id = id
        self.operation = operation
        self.startedAtNanoseconds = startedAtNanoseconds
        self.metadata = metadata
    }
}

/// One sampled timing event retained by the metrics provider.
public struct PerformanceMetricEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let operation: String
    public let stage: String
    public let durationMilliseconds: Double
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        operation: String,
        stage: String,
        durationMilliseconds: Double,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.operation = operation
        self.stage = stage
        self.durationMilliseconds = durationMilliseconds
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Aggregated latency statistics for one operation/stage pair.
public struct PerformanceMetricSummary: Codable, Equatable, Identifiable, Sendable {
    public let operation: String
    public let stage: String
    public let count: Int
    public let p50Milliseconds: Double
    public let p95Milliseconds: Double
    public let p99Milliseconds: Double
    public let maxMilliseconds: Double

    public var id: String { "\(operation).\(stage)" }

    public init(
        operation: String,
        stage: String,
        count: Int,
        p50Milliseconds: Double,
        p95Milliseconds: Double,
        p99Milliseconds: Double,
        maxMilliseconds: Double
    ) {
        self.operation = operation
        self.stage = stage
        self.count = count
        self.p50Milliseconds = p50Milliseconds
        self.p95Milliseconds = p95Milliseconds
        self.p99Milliseconds = p99Milliseconds
        self.maxMilliseconds = maxMilliseconds
    }
}

/// A point-in-time report consumed by settings and diagnostics UI.
public struct PerformanceMetricsReport: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let totalEventCount: Int
    public let summaries: [PerformanceMetricSummary]
    public let recentEvents: [PerformanceMetricEvent]

    public init(
        generatedAt: Date = Date(),
        totalEventCount: Int,
        summaries: [PerformanceMetricSummary],
        recentEvents: [PerformanceMetricEvent]
    ) {
        self.generatedAt = generatedAt
        self.totalEventCount = totalEventCount
        self.summaries = summaries
        self.recentEvents = recentEvents
    }
}

/// Central low-overhead performance reporting contract.
///
/// `begin`, `mark`, `end`, and `record` are synchronous by design. They only
/// update a bounded in-memory buffer; persistence and report generation are
/// moved to a utility-priority queue.
public protocol PerformanceMetricsProviding: AnyObject, Sendable {
    @discardableResult
    func begin(operation: String, metadata: [String: String]) -> PerformanceTrace

    func mark(
        _ trace: PerformanceTrace,
        stage: String,
        metadata: [String: String]
    )

    func end(
        _ trace: PerformanceTrace,
        metadata: [String: String]
    )

    func record(
        operation: String,
        stage: String,
        durationMilliseconds: Double,
        metadata: [String: String]
    )

    func report() async -> PerformanceMetricsReport

    func clear()
}

public extension PerformanceMetricsProviding {
    @discardableResult
    func begin(operation: String) -> PerformanceTrace {
        begin(operation: operation, metadata: [:])
    }

    func mark(_ trace: PerformanceTrace, stage: String) {
        mark(trace, stage: stage, metadata: [:])
    }

    func end(_ trace: PerformanceTrace) {
        end(trace, metadata: [:])
    }

    func record(
        operation: String,
        stage: String,
        durationMilliseconds: Double
    ) {
        record(
            operation: operation,
            stage: stage,
            durationMilliseconds: durationMilliseconds,
            metadata: [:]
        )
    }
}

/// Thread-safe default implementation used by the metrics plugin.
public final class DefaultPerformanceMetricsProvider: PerformanceMetricsProviding, @unchecked Sendable {
    private static let persistenceDelay: DispatchTimeInterval = .milliseconds(400)
    private static let recentEventLimit = 100

    private let lock = NSLock()
    private let persistenceQueue: DispatchQueue
    private let fileURL: URL?
    private let maxEventCount: Int

    private var events: [PerformanceMetricEvent] = []
    private var pendingWriteCount = 0
    private var persistenceScheduled = false

    public init(directoryURL: URL? = nil, maxEventCount: Int = 2_000) {
        self.fileURL = directoryURL?.appendingPathComponent("performance-metrics.json")
        self.maxEventCount = max(1, maxEventCount)
        self.persistenceQueue = DispatchQueue(
            label: "com.coffic.lumi.performance-metrics.persistence",
            qos: .utility,
            autoreleaseFrequency: .workItem
        )

        persistenceQueue.async { [weak self] in
            self?.loadFromDisk()
        }
    }

    @discardableResult
    public func begin(operation: String, metadata: [String: String] = [:]) -> PerformanceTrace {
        PerformanceTrace(
            operation: Self.sanitizedLabel(operation),
            startedAtNanoseconds: DispatchTime.now().uptimeNanoseconds,
            metadata: Self.sanitizedMetadata(metadata)
        )
    }

    public func mark(
        _ trace: PerformanceTrace,
        stage: String,
        metadata: [String: String] = [:]
    ) {
        record(
            operation: trace.operation,
            stage: stage,
            durationMilliseconds: Self.elapsedMilliseconds(since: trace.startedAtNanoseconds),
            metadata: trace.metadata.merging(Self.sanitizedMetadata(metadata)) { _, new in new }
        )
    }

    public func end(
        _ trace: PerformanceTrace,
        metadata: [String: String] = [:]
    ) {
        mark(trace, stage: "total", metadata: metadata)
    }

    public func record(
        operation: String,
        stage: String,
        durationMilliseconds: Double,
        metadata: [String: String] = [:]
    ) {
        guard durationMilliseconds.isFinite, durationMilliseconds >= 0 else { return }

        let event = PerformanceMetricEvent(
            operation: Self.sanitizedLabel(operation),
            stage: Self.sanitizedLabel(stage),
            durationMilliseconds: durationMilliseconds,
            metadata: Self.sanitizedMetadata(metadata)
        )

        lock.lock()
        events.append(event)
        if events.count > maxEventCount {
            events.removeFirst(events.count - maxEventCount)
        }
        pendingWriteCount += 1
        let shouldSchedulePersistence = !persistenceScheduled
        if shouldSchedulePersistence {
            persistenceScheduled = true
        }
        lock.unlock()

        if shouldSchedulePersistence {
            persistenceQueue.asyncAfter(deadline: .now() + Self.persistenceDelay) { [weak self] in
                self?.persistSnapshot()
            }
        }
    }

    public func report() async -> PerformanceMetricsReport {
        await withCheckedContinuation { continuation in
            // The initial load is queued before report requests, so this also
            // makes the first settings refresh include persisted data.
            persistenceQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(
                        returning: PerformanceMetricsReport(
                            totalEventCount: 0,
                            summaries: [],
                            recentEvents: []
                        )
                    )
                    return
                }
                continuation.resume(returning: self.makeReport())
            }
        }
    }

    public func clear() {
        lock.lock()
        events.removeAll(keepingCapacity: true)
        pendingWriteCount = 0
        persistenceScheduled = false
        lock.unlock()

        persistenceQueue.async { [weak self] in
            guard let fileURL = self?.fileURL else { return }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let fileURL else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? Data(contentsOf: fileURL),
              let persistedEvents = try? JSONDecoder().decode([PerformanceMetricEvent].self, from: data)
        else { return }

        lock.lock()
        events = Array((persistedEvents + events).suffix(maxEventCount))
        lock.unlock()
    }

    private func persistSnapshot() {
        let snapshot: [PerformanceMetricEvent]
        lock.lock()
        snapshot = events
        pendingWriteCount = 0
        persistenceScheduled = false
        lock.unlock()

        if let fileURL,
           let data = try? JSONEncoder().encode(snapshot) {
            try? FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: fileURL, options: .atomic)
        }

        lock.lock()
        let shouldSchedulePersistence = pendingWriteCount > 0 && !persistenceScheduled
        if shouldSchedulePersistence {
            persistenceScheduled = true
        }
        lock.unlock()

        if shouldSchedulePersistence {
            persistenceQueue.asyncAfter(deadline: .now() + Self.persistenceDelay) { [weak self] in
                self?.persistSnapshot()
            }
        }
    }

    // MARK: - Reports

    private func makeReport() -> PerformanceMetricsReport {
        lock.lock()
        let snapshot = events
        lock.unlock()

        let grouped = Dictionary(grouping: snapshot) { event in
            "\(event.operation)\u{1F}\(event.stage)"
        }
        let summaries = grouped.values.compactMap { values -> PerformanceMetricSummary? in
            guard let first = values.first else { return nil }
            let sortedDurations = values.map(\.durationMilliseconds).sorted()
            return PerformanceMetricSummary(
                operation: first.operation,
                stage: first.stage,
                count: sortedDurations.count,
                p50Milliseconds: Self.percentile(sortedDurations, percentile: 0.50),
                p95Milliseconds: Self.percentile(sortedDurations, percentile: 0.95),
                p99Milliseconds: Self.percentile(sortedDurations, percentile: 0.99),
                maxMilliseconds: sortedDurations.last ?? 0
            )
        }
        .sorted {
            if $0.operation == $1.operation { return $0.stage < $1.stage }
            return $0.operation < $1.operation
        }

        return PerformanceMetricsReport(
            totalEventCount: snapshot.count,
            summaries: summaries,
            recentEvents: Array(snapshot.suffix(Self.recentEventLimit).reversed())
        )
    }

    private static func percentile(_ sortedValues: [Double], percentile: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        let index = min(
            sortedValues.count - 1,
            max(0, Int(ceil(Double(sortedValues.count) * percentile)) - 1)
        )
        return sortedValues[index]
    }

    private static func elapsedMilliseconds(since start: UInt64) -> Double {
        let now = DispatchTime.now().uptimeNanoseconds
        return Double(now >= start ? now - start : 0) / 1_000_000
    }

    private static func sanitizedLabel(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(80)).isEmpty ? "unknown" : String(trimmed.prefix(80))
    }

    private static func sanitizedMetadata(_ metadata: [String: String]) -> [String: String] {
        metadata.reduce(into: [:]) { result, item in
            let key = String(item.key.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
            let value = String(item.value.prefix(120))
            guard !key.isEmpty, !value.isEmpty else { return }
            result[key] = value
        }
    }
}
