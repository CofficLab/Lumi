import Foundation

actor ReviewReportStore {
    static let shared = ReviewReportStore()

    private var latestReports: [String: ReviewReport] = [:]
    private var state: ReviewState = .idle

    func setState(_ state: ReviewState) {
        self.state = state
    }

    func currentState() -> ReviewState {
        state
    }

    func save(_ report: ReviewReport) throws {
        latestReports[key(repositoryPath: report.repositoryPath, scope: report.scope)] = report
        try persist(report)
        state = .completed(reportId: report.id)
    }

    func latest(repositoryPath: String, scope: ReviewScope) -> ReviewReport? {
        latestReports[key(repositoryPath: repositoryPath, scope: scope)]
    }

    func issueCounts(for report: ReviewReport) -> [ReviewSeverity: Int] {
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
}

private extension JSONEncoder {
    static var reviewEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

enum ReviewReportStoreError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "Application Support directory is unavailable."
        }
    }
}
