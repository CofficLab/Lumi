import Foundation

/// Granular progress while `XcodeBuildContextProvider` resolves build context.
public struct BuildContextResolutionProgress: Equatable, Sendable {
    public enum Phase: String, Sendable, CaseIterable {
        case locatingWorkspace
        case discoveringSchemes
        case parsingProjectMembership
        case runningXcodebuildList
        case selectingScheme
        case generatingBuildServer
        case indexingCompileDatabase
    }

    public struct Update: Sendable, Equatable {
        public let phase: Phase
        public var detail: String?
        public var currentItem: String?

        public init(phase: Phase, detail: String? = nil, currentItem: String? = nil) {
            self.phase = phase
            self.detail = detail
            self.currentItem = currentItem
        }
    }

    public let phase: Phase
    public var detail: String?
    public var currentItem: String?
    public let startedAt: Date

    public init(phase: Phase, detail: String? = nil, currentItem: String? = nil, startedAt: Date = Date()) {
        self.phase = phase
        self.detail = detail
        self.currentItem = currentItem
        self.startedAt = startedAt
    }

    public init(updating previous: BuildContextResolutionProgress?, with update: Update) {
        if let previous, previous.phase == update.phase {
            self.phase = update.phase
            self.detail = update.detail ?? previous.detail
            self.currentItem = update.currentItem ?? previous.currentItem
            self.startedAt = previous.startedAt
        } else {
            self.phase = update.phase
            self.detail = update.detail
            self.currentItem = update.currentItem
            self.startedAt = Date()
        }
    }

    public var displayDescription: String {
        var parts = [phaseDisplayDescription]
        if let currentItem, !currentItem.isEmpty {
            parts.append(currentItem)
        } else if let detail, !detail.isEmpty {
            parts.append(detail)
        }
        return parts.joined(separator: " · ")
    }

    public var phaseDisplayDescription: String {
        switch phase {
        case .locatingWorkspace:
            return "Locating workspace..."
        case .discoveringSchemes:
            return "Discovering schemes..."
        case .parsingProjectMembership:
            return "Parsing project membership..."
        case .runningXcodebuildList:
            return "Running xcodebuild -list..."
        case .selectingScheme:
            return "Selecting scheme..."
        case .generatingBuildServer:
            return "Generating buildServer.json..."
        case .indexingCompileDatabase:
            return "Building semantic index..."
        }
    }

    public static func formattedElapsed(since date: Date, now: Date = Date()) -> String {
        let totalSeconds = max(0, Int(now.timeIntervalSince(date)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(seconds)s"
    }

    public func showsElapsedTime(at now: Date = Date()) -> Bool {
        switch phase {
        case .runningXcodebuildList, .generatingBuildServer, .parsingProjectMembership:
            return now.timeIntervalSince(startedAt) >= 1
        default:
            return false
        }
    }
}

/// Throttles high-frequency scan progress callbacks.
final class ThrottledScanProgressReporter: @unchecked Sendable {
    private let minimumInterval: TimeInterval
    private let lock = NSLock()
    private nonisolated(unsafe) var lastReportedAt: Date = .distantPast

    init(minimumInterval: TimeInterval = 0.25) {
        self.minimumInterval = minimumInterval
    }

    func report(_ path: String, handler: @Sendable (String) -> Void) {
        let now = Date()
        lock.lock()
        defer { lock.unlock() }
        guard now.timeIntervalSince(lastReportedAt) >= minimumInterval else { return }
        lastReportedAt = now
        handler(path)
    }
}
