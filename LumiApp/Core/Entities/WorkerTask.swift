import Foundation

/// Worker 任务模型
struct WorkerTask: Identifiable, Sendable, Equatable {
    let id: UUID
    var description: String
    var assignedTo: UUID?
    var status: WorkerTaskStatus
    var result: String?
    let createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        description: String,
        assignedTo: UUID? = nil,
        status: WorkerTaskStatus = .pending,
        result: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.description = description
        self.assignedTo = assignedTo
        self.status = status
        self.result = result
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

enum WorkerTaskStatus: Sendable, Equatable {
    case pending
    case running
    case completed
    case failed
}
