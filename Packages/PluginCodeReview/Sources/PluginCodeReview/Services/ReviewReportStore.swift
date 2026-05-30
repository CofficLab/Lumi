import Foundation

public actor ReviewReportStore {
    public static let shared = ReviewReportStore()

    private let maxInMemoryReports = 20
    private var latestReports: [String: ReviewReport] = [:]
    private var reportKeysByRecency: [String] = []
    private var state: ReviewState = .idle

    public func setState(_ state: ReviewState) {
        self.state = state
    }

    public func currentState() -> ReviewState {
        state
    }

    public func save(_ report: ReviewReport) throws {
        let key = key(repositoryPath: report.repositoryPath, scope: report.scope)
        latestReports[key] = report
        markRecentlyUsed(key)
        trimInMemoryReportsIfNeeded()
        try persist(report)
        state = .completed(reportId: report.id)
    }

    public func latest(repositoryPath: String, scope: ReviewScope) -> ReviewReport? {
        let key = key(repositoryPath: repositoryPath, scope: scope)
        guard let report = latestReports[key] else { return nil }
        markRecentlyUsed(key)
        return report
    }

    public func issueCounts(for report: ReviewReport) -> [ReviewSeverity: Int] {
        Dictionary(grouping: report.issues, by: \.severity).mapValues(\.count)
    }

    private func persist(_ report: ReviewReport) throws {
        let directory = try reportsDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.reviewEncoder.encode(report)
        try data.write(to: directory.appendingPathComponent("\(report.id.uuidString).json"), options: [.atomic])
    }

    private func reportsDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base else {
            throw ReviewReportStoreError.applicationSupportUnavailable
        }
        return base
            .appendingPathComponent("Lumi", isDirectory: true)
            .appendingPathComponent("CodeReviewReports", isDirectory: true)
    }

    private func key(repositoryPath: String, scope: ReviewScope) -> String {
        "\(repositoryPath)#\(scope.rawValue)"
    }

    private func markRecentlyUsed(_ key: String) {
        reportKeysByRecency.removeAll { $0 == key }
        reportKeysByRecency.append(key)
    }

    private func trimInMemoryReportsIfNeeded() {
        while reportKeysByRecency.count > maxInMemoryReports {
            let oldestKey = reportKeysByRecency.removeFirst()
            latestReports.removeValue(forKey: oldestKey)
        }
    }
}

private extension JSONEncoder {
    public static var reviewEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public enum ReviewReportStoreError: LocalizedError {
    case applicationSupportUnavailable

    public var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "Application Support directory is unavailable."
        }
    }
}
