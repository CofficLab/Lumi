import Foundation
import LumiCoreKit

enum KernelSubAgentStatus: String, Sendable {
    case running
    case completed
    case failed
    case cancelled
}

struct KernelSubAgentResult: Sendable {
    let taskId: String
    let type: String
    let name: String
    let status: KernelSubAgentStatus
    let fields: [String: String]
    let rawOutput: String
    let error: String?
    let duration: Double
}

final class KernelSubAgentTask: @unchecked Sendable {
    let id: String
    let type: String
    let name: String
    let createdAt: Date

    var status: KernelSubAgentStatus
    var handle: Task<Void, Never>?
    var result: KernelSubAgentResult?

    init(id: String, type: String, name: String) {
        self.id = id
        self.type = type
        self.name = name
        self.createdAt = Date()
        self.status = .running
    }
}
