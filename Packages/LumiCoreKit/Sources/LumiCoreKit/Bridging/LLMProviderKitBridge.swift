import Foundation
import LLMProviderKit
import AgentToolKit

// MARK: - SuperAgentTool 桥接到 LLMToolSchemaProviding

/// 将 SuperAgentTool 包装为 LLMToolSchemaProviding 的适配器
public struct SuperAgentToolBridge: LLMToolSchemaProviding {
    public let tool: any SuperAgentTool

    public init(tool: any SuperAgentTool) {
        self.tool = tool
    }

    public var name: String { tool.name }
    public var toolDescription: String { tool.description(for: .english) }
    public var inputSchema: [String: Any] { tool.inputSchema(for: .english) }
}

// MARK: - MessageRole 转换

extension LLMProviderKit.MessageRole {
    public init(app role: MessageRole) {
        switch role {
        case .system:    self = .system
        case .user:      self = .user
        case .assistant: self = .assistant
        case .tool:      self = .tool
        case .status:    self = .status
        case .error:     self = .error
        case .unknown:   self = .unknown
        }
    }
}

extension MessageRole {
    public init(kit role: LLMProviderKit.MessageRole) {
        switch role {
        case .system:    self = .system
        case .user:      self = .user
        case .assistant: self = .assistant
        case .tool:      self = .tool
        case .status:    self = .status
        case .error:     self = .error
        case .unknown:   self = .unknown
        }
    }
}

// MARK: - ToolCall 转换

extension LLMProviderKit.ToolCall {
    public init(app toolCall: AgentToolKit.ToolCall) {
        self.init(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
    }
}

extension AgentToolKit.ToolCall {
    public init(kit toolCall: LLMProviderKit.ToolCall) {
        self.init(id: toolCall.id, name: toolCall.name, arguments: toolCall.arguments)
    }
}

// MARK: - ChatMessage 转换

extension LLMProviderKit.ChatMessage {
    public init(app message: ChatMessage) {
        self.init(
            id: message.id,
            role: LLMProviderKit.MessageRole(app: message.role),
            content: message.content,
            toolCalls: message.toolCalls?.map { LLMProviderKit.ToolCall(app: $0) },
            toolCallID: message.toolCallID,
            reasoningContent: message.thinkingContent
        )
    }
}

// MARK: - StreamChunk 转换

extension StreamChunk {
    public init(kit chunk: LLMProviderKit.StreamChunk) {
        self.init(
            content: chunk.content,
            isDone: chunk.isDone,
            toolCalls: chunk.toolCalls?.map { AgentToolKit.ToolCall(kit: $0) },
            error: chunk.error,
            partialJson: chunk.partialJson,
            eventType: chunk.eventType.map { StreamEventType(kit: $0) },
            rawEvent: chunk.rawEvent,
            rawStreamPayload: chunk.rawStreamPayload,
            inputTokens: chunk.inputTokens,
            outputTokens: chunk.outputTokens,
            stopReason: chunk.stopReason
        )
    }
}

// MARK: - StreamEventType 转换

extension StreamEventType {
    public init(kit type: LLMProviderKit.StreamEventType) {
        switch type {
        case .messageStart:       self = .messageStart
        case .messageDelta:       self = .messageDelta
        case .messageStop:        self = .messageStop
        case .contentBlockStart:  self = .contentBlockStart
        case .contentBlockDelta:  self = .contentBlockDelta
        case .contentBlockStop:   self = .contentBlockStop
        case .thinkingDelta:      self = .thinkingDelta
        case .textDelta:          self = .textDelta
        case .inputJsonDelta:     self = .inputJsonDelta
        case .signatureDelta:     self = .signatureDelta
        case .ping:               self = .ping
        case .unknown:            self = .unknown
        }
    }
}
