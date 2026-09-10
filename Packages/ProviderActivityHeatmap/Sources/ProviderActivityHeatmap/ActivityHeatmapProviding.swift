import Foundation

/// One calendar day's local Git activity.
public struct ActivityHeatmapDay: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let date: Date
    public let commitCount: Int

    public var id: Date { date }

    public init(date: Date, commitCount: Int) {
        self.date = date
        self.commitCount = max(0, commitCount)
    }
}

/// A repository-scoped activity snapshot consumed by settings UI.
public struct ActivityHeatmapSnapshot: Codable, Equatable, Sendable {
    public let repositoryPath: String
    public let generatedAt: Date
    public let days: [ActivityHeatmapDay]

    public init(repositoryPath: String, generatedAt: Date, days: [ActivityHeatmapDay]) {
        self.repositoryPath = repositoryPath
        self.generatedAt = generatedAt
        self.days = days.sorted { $0.date < $1.date }
    }
}

@MainActor
public enum ActivityHeatmapEvent: Equatable {
    case snapshotChanged
    case loadingChanged
}

@MainActor
public protocol ActivityHeatmapObserverHandle: AnyObject {
    func cancel()
}

/// Shared, source-agnostic contract for a Git-style activity heatmap.
@MainActor
public protocol ActivityHeatmapProviding: AnyObject {
    var currentSnapshot: ActivityHeatmapSnapshot? { get }
    var isLoading: Bool { get }

    func refresh(for repositoryURL: URL?)

    @discardableResult
    func addObserver(
        _ callback: @escaping (ActivityHeatmapEvent) -> Void
    ) -> any ActivityHeatmapObserverHandle
}
