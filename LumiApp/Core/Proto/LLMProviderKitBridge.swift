import Foundation
import LLMProviderKit

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

// MARK: - Kit 类型别名
//
// 注意：不能使用 private/fileprivate，因为扩展初始化方法需要能被其他文件看到。
// 这些类型别名仅供本文件内部使用，但 Swift 没有"仅限本文件可见的类型别名但允许跨文件扩展"的机制。
// 因此我们使用前缀命名来避免冲突。

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
    init(app toolCall: ToolCall) {
        self.init(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
    }
}

extension ToolCall {
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
            toolCallID: message.toolCallID
        )
    }
}

// MARK: - StreamChunk 转换

extension StreamChunk {
    init(kit chunk: LLMProviderKit.StreamChunk) {
        self.init(
            content: chunk.content,
            isDone: chunk.isDone,
            toolCalls: chunk.toolCalls?.map { ToolCall(kit: $0) },
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
