import Foundation

/// Worker 实例模型
///
/// 用于表示一次任务执行期间创建的后台 Worker。
struct WorkerAgent: Identifiable, Sendable, Equatable {
    let id: UUID
    var name: String
    var type: WorkerAgentType
    var description: String
    var specialty: String
    var config: LLMConfig
    var status: WorkerStatus
    var currentTask: WorkerTask?
    var messageHistory: [ChatMessage]
    var systemPrompt: String
    let createdAt: Date
    var lastActiveAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: WorkerAgentType,
        description: String,
        specialty: String,
        config: LLMConfig,
        status: WorkerStatus = .idle,
        currentTask: WorkerTask? = nil,
        messageHistory: [ChatMessage] = [],
        systemPrompt: String,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.specialty = specialty
        self.config = config
        self.status = status
        self.currentTask = currentTask
        self.messageHistory = messageHistory
        self.systemPrompt = systemPrompt
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
}
