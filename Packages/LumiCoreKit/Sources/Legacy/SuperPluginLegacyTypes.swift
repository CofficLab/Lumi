import SwiftUI

// MARK: - Legacy plugin types (Editor extension packages)

public enum PluginCategory: String, Sendable, Codable, CaseIterable {
    case general
    case editor
    case agent
    case development
    case theme
    case llmProvider = "llm_provider"
}

public struct PluginContext: Sendable {
    public var activeIcon: String
    public var showsRail: Bool
    public var showsBottomPanel: Bool

    public init(
        activeIcon: String = "chevron.left.forwardslash.chevron.right",
        showsRail: Bool = true,
        showsBottomPanel: Bool = true
    ) {
        self.activeIcon = activeIcon
        self.showsRail = showsRail
        self.showsBottomPanel = showsBottomPanel
    }
}

public struct BottomPanelTab: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let priority: Int

    public init(id: String, title: String, systemImage: String, priority: Int) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.priority = priority
    }
}

public struct RailItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let priority: Int
    public let makeView: @MainActor @Sendable () -> AnyView

    public init(
        id: String,
        title: String,
        systemImage: String,
        priority: Int,
        makeView: @escaping @MainActor @Sendable () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.priority = priority
        self.makeView = makeView
    }
}

@MainActor
public final class PluginRuntimeContext {
    public var editorServiceProvider: @MainActor (PluginContext) -> AnyObject?
    public var currentProjectPath: @MainActor (PluginContext) -> String?
    public var editorThemeId: @MainActor () -> String = { "xcode-dark" }
    public var addToChat: @MainActor (String, PluginContext) -> Void = { _, _ in }
    public var openFile: @MainActor (URL, String?, PluginContext) async -> Void = { _, _, _ in }

    // MARK: - Agent pipeline

    public var agentConversationStore: (any AgentConversationStore)?
    public var llmSendService: (any AgentLLMSendService)?
    public var loadMessages: @MainActor (UUID) -> [AgentChatMessage] = { _ in [] }
    public var loadTurnPhase: @MainActor (UUID) -> AgentTurnPhase = { _ in .idle }
    public var setTurnPhase: @MainActor (AgentTurnPhase, UUID) -> Void = { phase, conversationID in
        AgentTurnLifecycle.postPhaseChanged(phase, conversationID: conversationID)
    }
    public var tryAcquireConversationLock: @MainActor (UUID) -> Bool = { _ in false }
    public var releaseConversationLock: @MainActor (UUID) -> Void = { _ in }
    public var isConversationCancelled: @MainActor (UUID) -> Bool = { _ in false }
    public var clearConversationCancelled: @MainActor (UUID) -> Void = { _ in }
    public var dequeueNextPendingMessage: @MainActor (UUID) -> AgentChatMessage? = { _ in nil }
    public var runSendPreparePipeline: @MainActor (UUID, AgentChatMessage) async -> [String] = { _, _ in [] }
    public var storeTransientSystemPrompts: @MainActor ([String], UUID) -> Void = { _, _ in }
    public var prepareMessagesForLLM: @MainActor (UUID, [AgentChatMessage]) -> [AgentChatMessage] = { _, messages in messages }
    public var consumeTransientSystemPrompts: @MainActor (UUID) -> [String] = { _ in [] }
    public var presentToolPermissionIfNeeded: @MainActor (AgentChatMessage, UUID) async -> Bool = { _, _ in false }
    public var executeToolCalls: @MainActor (AgentChatMessage, UUID) async -> ToolExecutionSummary = { _, _ in ToolExecutionSummary() }
    public var setConversationStatus: @MainActor (UUID, String) -> Void = { _, _ in }
    public var finishAgentTurn: @MainActor (UUID, TurnEndReason) -> Void = { conversationID, reason in
        AgentTurnLifecycle.postTurnFinished(conversationID: conversationID, reason: reason)
    }

    public init(
        editorServiceProvider: @escaping @MainActor (PluginContext) -> AnyObject? = { _ in nil },
        currentProjectPath: @escaping @MainActor (PluginContext) -> String? = { _ in nil }
    ) {
        self.editorServiceProvider = editorServiceProvider
        self.currentProjectPath = currentProjectPath
    }
}

/// Host hook for language editor plugins that need `PluginRuntimeContext` after the editor shell wires bridges.
@MainActor
public enum EditorLanguageRuntimeBridge {
    public static var configure: (@MainActor (PluginRuntimeContext) async -> Void)?
}

/// Legacy tool execution context retained for editor extension packages.
public struct ToolContext: Sendable {
    public var currentProjectPath: String?

    public init(currentProjectPath: String? = nil) {
        self.currentProjectPath = currentProjectPath
    }
}
