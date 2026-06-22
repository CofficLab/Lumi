import Foundation

public enum AgentChatMessageRole: String, Codable, Sendable, Equatable, CaseIterable {
  case system
  case user
  case assistant
  case tool
  case error
  case status
}

public enum AgentChatQueueStatus: String, Codable, Sendable, Equatable {
  case pending
  case sent
}

public struct AgentChatToolCall: Codable, Sendable, Equatable {
  public let id: String
  public let name: String
  public let arguments: String

  public init(id: String, name: String, arguments: String) {
    self.id = id
    self.name = name
    self.arguments = arguments
  }
}

/// Agent 管线持久化消息模型（与 `LumiChatMessage` 平行，供插件侧推导使用）。
public struct AgentChatMessage: Identifiable, Sendable, Equatable {
  public let id: UUID
  public let role: AgentChatMessageRole
  public let conversationId: UUID
  public var content: String
  public var timestamp: Date
  public var queueStatus: AgentChatQueueStatus?
  public var toolCalls: [AgentChatToolCall]?
  public var toolCallID: String?
  public var isError: Bool
  public var rawErrorDetail: String?
  public var providerId: String?
  public var modelName: String?

  public init(
    id: UUID = UUID(),
    role: AgentChatMessageRole,
    conversationId: UUID,
    content: String,
    timestamp: Date = Date(),
    queueStatus: AgentChatQueueStatus? = nil,
    toolCalls: [AgentChatToolCall]? = nil,
    toolCallID: String? = nil,
    isError: Bool = false,
    rawErrorDetail: String? = nil,
    providerId: String? = nil,
    modelName: String? = nil
  ) {
    self.id = id
    self.role = role
    self.conversationId = conversationId
    self.content = content
    self.timestamp = timestamp
    self.queueStatus = queueStatus
    self.toolCalls = toolCalls
    self.toolCallID = toolCallID
    self.isError = isError
    self.rawErrorDetail = rawErrorDetail
    self.providerId = providerId
    self.modelName = modelName
  }
}
