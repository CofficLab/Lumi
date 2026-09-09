import Foundation
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming
import ProviderProject
import ProviderPromptSuggestion
import ProviderToolbar
import ProviderToolManager

// MARK: - 会话

/// 会话列表所需的最小会话能力。
@MainActor
protocol MessageListConversationCapability: AnyObject {
    var selectedConversationID: UUID? { get }
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity
}

@MainActor
final class MessageListConversationCapabilityAdapter: MessageListConversationCapability {
    private let conversations: any ConversationManaging
    init(conversations: any ConversationManaging) { self.conversations = conversations }
    var selectedConversationID: UUID? { conversations.selectedConversationID }
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        conversations.verbosity(for: conversationID)
    }
}

// MARK: - 会话状态

/// 会话活动状态所需的最小会话状态能力。
@MainActor
protocol MessageListConversationStateCapability: AnyObject {
    func state(for conversationID: UUID) -> ConversationStateSnapshot
}

@MainActor
final class MessageListConversationStateCapabilityAdapter: MessageListConversationStateCapability {
    private let conversationState: any ConversationStateProviding
    init(conversationState: any ConversationStateProviding) { self.conversationState = conversationState }
    func state(for conversationID: UUID) -> ConversationStateSnapshot {
        conversationState.state(for: conversationID)
    }
}

// MARK: - 消息

/// 消息读取所需的最小消息能力。
@MainActor
protocol MessageListMessageCapability: AnyObject {
    func messagesSnapshot(in conversationID: UUID) async -> [Message]
    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message]
    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool
}

@MainActor
final class MessageListMessageCapabilityAdapter: MessageListMessageCapability {
    private let messages: any MessageManaging
    init(messages: any MessageManaging) { self.messages = messages }
    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        await messages.messagesSnapshot(in: conversationID)
    }
    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        await messages.messagePageAsync(
            for: conversationID,
            limit: limit,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages
        )
    }
    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool {
        await messages.hasEarlierMessagesAsync(
            for: conversationID,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages
        )
    }
}

// MARK: - 渲染

/// 消息渲染所需的最小渲染能力。
@MainActor
protocol MessageListRenderingCapability: AnyObject {
    func renderer(for message: Message) -> MessageRendererItem?
}

@MainActor
final class MessageListRenderingCapabilityAdapter: MessageListRenderingCapability {
    private let rendering: any MessageRenderingProviding
    init(rendering: any MessageRenderingProviding) { self.rendering = rendering }
    func renderer(for message: Message) -> MessageRendererItem? {
        rendering.renderer(for: message)
    }
}

// MARK: - 流式

/// 流式消息展示所需的最小流式能力。
@MainActor
protocol MessageListStreamingCapability: AnyObject {
    func streamingMessage(for conversationID: UUID) -> Message?
    func stage(for conversationID: UUID) -> MessageStreamingStage
}

@MainActor
final class MessageListStreamingCapabilityAdapter: MessageListStreamingCapability {
    private let streaming: any MessageStreamingProviding
    init(streaming: any MessageStreamingProviding) { self.streaming = streaming }
    func streamingMessage(for conversationID: UUID) -> Message? {
        streaming.streamingMessage(for: conversationID)
    }
    func stage(for conversationID: UUID) -> MessageStreamingStage {
        streaming.stage(for: conversationID)
    }
}

// MARK: - 工具

/// 工具调用展示与取消所需的最小工具能力。
@MainActor
protocol MessageListToolManagerCapability: AnyObject {
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord]
    func cancelJobs(forTurnID turnID: UUID)
}

@MainActor
final class MessageListToolManagerCapabilityAdapter: MessageListToolManagerCapability {
    private let toolManager: any ToolManagerProviding
    init(toolManager: any ToolManagerProviding) { self.toolManager = toolManager }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        await toolManager.toolCalls(for: turnID)
    }
    func cancelJobs(forTurnID turnID: UUID) {
        toolManager.cancelJobs(forTurnID: turnID)
    }
}

// MARK: - Agent 回合

/// Agent 回合状态所需的最小能力。
@MainActor
protocol MessageListAgentLoopCapability: AnyObject {
    func state(for conversationID: UUID) -> AgentLoopState
}

@MainActor
final class MessageListAgentLoopCapabilityAdapter: MessageListAgentLoopCapability {
    private let agentTurn: any AgentLoopProviding
    init(agentTurn: any AgentLoopProviding) { self.agentTurn = agentTurn }
    func state(for conversationID: UUID) -> AgentLoopState {
        agentTurn.state(for: conversationID)
    }
}

// MARK: - 提示建议

/// 提示建议展示所需的最小能力。
@MainActor
protocol MessageListPromptSuggestionCapability: AnyObject {
    var allSuggestions: [PromptSuggestion] { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PromptSuggestionProvidingEvent) -> Void
    ) -> any PromptSuggestionProvidingObserverHandle
}

@MainActor
final class MessageListPromptSuggestionCapabilityAdapter: MessageListPromptSuggestionCapability {
    private let promptSuggestions: any PromptSuggestionProviding
    init(promptSuggestions: any PromptSuggestionProviding) { self.promptSuggestions = promptSuggestions }
    var allSuggestions: [PromptSuggestion] { promptSuggestions.allSuggestions }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PromptSuggestionProvidingEvent) -> Void
    ) -> any PromptSuggestionProvidingObserverHandle {
        promptSuggestions.addObserver(callback)
    }
}

/// 提示建议执行所需的最小能力。
@MainActor
protocol MessageListPromptSuggestionExecutorCapability: AnyObject {
    func execute(_ suggestion: PromptSuggestion, pickProjectFolder: (() -> Void)?) async
}

@MainActor
final class MessageListPromptSuggestionExecutorCapabilityAdapter: MessageListPromptSuggestionExecutorCapability {
    private let executor: any PromptSuggestionExecuting
    init(executor: any PromptSuggestionExecuting) { self.executor = executor }
    func execute(_ suggestion: PromptSuggestion, pickProjectFolder: (() -> Void)?) async {
        await executor.execute(suggestion, pickProjectFolder: pickProjectFolder)
    }
}

// MARK: - 项目

/// 消息列表所需的最小项目能力。
@MainActor
protocol MessageListProjectCapability: AnyObject {
    var currentProject: ProjectInfo? { get }
    var projects: [ProjectInfo] { get }
    func openProject(at path: String) async throws
}

@MainActor
final class MessageListProjectCapabilityAdapter: MessageListProjectCapability {
    private let project: any ProjectProviding
    init(project: any ProjectProviding) { self.project = project }
    var currentProject: ProjectInfo? { project.currentProject }
    var projects: [ProjectInfo] { project.projects }
    func openProject(at path: String) async throws {
        try await project.openProject(at: path)
    }
}

// MARK: - 工具栏

/// 空态工具栏控制所需的最小工具栏能力。
@MainActor
protocol MessageListToolbarCapability: AnyObject {
    func setHiddenCategories(_ categories: Set<ToolbarItemCategory>, for source: String)
}

@MainActor
final class MessageListToolbarCapabilityAdapter: MessageListToolbarCapability {
    private let toolbar: any ToolbarProviding
    init(toolbar: any ToolbarProviding) { self.toolbar = toolbar }
    func setHiddenCategories(_ categories: Set<ToolbarItemCategory>, for source: String) {
        toolbar.setHiddenCategories(categories, for: source)
    }
}

// MARK: - 会话区

/// 会话区上下文所需的最小能力。
@MainActor
protocol MessageListChatSectionCapability: AnyObject {
    var activeContext: ChatContext? { get }
}

@MainActor
final class MessageListChatSectionCapabilityAdapter: MessageListChatSectionCapability {
    private let chat: any ChatSectionProviding
    init(chat: any ChatSectionProviding) { self.chat = chat }
    var activeContext: ChatContext? { chat.activeContext }
}
