import Foundation
import LLMProviderKit
import ToolKit

// MARK: - SuperAgentTool 桥接到 LLMToolSchemaProviding
//
// Swift 不允许在 extension 中添加继承子句，所以我们用一个轻量包装类型来桥接。

/// 将 SuperAgentTool 包装为 LLMToolSchemaProviding 的适配器
struct SuperAgentToolBridge: LLMToolSchemaProviding {
    let tool: any SuperAgentTool

    var name: String { tool.name }
    var toolDescription: String { tool.description(for: .english) }
    var inputSchema: [String: Any] { tool.inputSchema(for: .english) }
}

// MARK: - MessageRole 转换

extension LLMProviderKit.MessageRole {
    init(app role: MessageRole) {
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
    init(kit role: LLMProviderKit.MessageRole) {
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
    init(app toolCall: ToolKit.ToolCall) {
        self.init(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
    }
}

extension ToolKit.ToolCall {
    init(kit toolCall: LLMProviderKit.ToolCall) {
        self.init(id: toolCall.id, name: toolCall.name, arguments: toolCall.arguments)
    }
}

// MARK: - ChatMessage 转换

extension LLMProviderKit.ChatMessage {
    init(app message: ChatMessage) {
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
    init(kit chunk: LLMProviderKit.StreamChunk) {
        self.init(
            content: chunk.content,
            isDone: chunk.isDone,
            toolCalls: chunk.toolCalls?.map { ToolKit.ToolCall(kit: $0) },
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
    init(kit type: LLMProviderKit.StreamEventType) {
        switch type {
        case .messageStart:       self = .messageStart
        case .messageDelta:       self = .messageDelta
        case .messageStop:        self = .messageStop
        case .contentBlockStart:  self = .contentBlockStart
        case .contentBlockDelta:  self = .contentBlockDelta
        case .contentBlockStop:  self = .contentBlockStop
        case .thinkingDelta:      self = .thinkingDelta
        case .textDelta:          self = .textDelta
        case .inputJsonDelta:     self = .inputJsonDelta
        case .signatureDelta:     self = .signatureDelta
        case .ping:               self = .ping
        case .unknown:            self = .unknown
        }
    }
}
