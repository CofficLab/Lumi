import Foundation
import SwiftData

@Model
final class BackgroundAgentTask {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var originalPrompt: String
    var statusRawValue: String
    var resultSummary: String?
    var errorDescription: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        originalPrompt: String,
        statusRawValue: String = BackgroundAgentTaskStatus.pending.rawValue,
        resultSummary: String? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.originalPrompt = originalPrompt
        self.statusRawValue = statusRawValue
        self.resultSummary = resultSummary
        self.errorDescription = errorDescription
    }
}

enum BackgroundAgentTaskStatus: String {
    case pending
    case running
    case succeeded
    case failed

    init(rawOrDefault raw: String) {
        self = BackgroundAgentTaskStatus(rawValue: raw) ?? .pending
    }
}

