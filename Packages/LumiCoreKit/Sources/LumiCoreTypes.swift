import Foundation
import LumiCoreGit
import LumiCoreLayout

// MARK: - Git Component Types

public typealias GitComponent = LumiCoreGit.GitComponent
public typealias GitAccessCoordinator = LumiCoreGit.GitAccessCoordinator

// MARK: - Layout Component Types

public typealias LayoutComponent = LumiCoreLayout.LayoutComponent
public typealias LayoutState = LumiCoreLayout.LayoutState
public typealias LayoutEventPayload = LumiCoreLayout.LayoutEventPayload

// MARK: - Logo Component Types

public typealias LogoComponent = LumiCoreLayout.LogoComponent
public typealias LogoItem = LumiCoreLayout.LogoItem
public typealias LogoScene = LumiCoreLayout.LogoScene

// MARK: - Chat Section Types

public typealias LumiChatSectionLayout = LumiCoreLayout.LumiChatSectionLayout
public typealias LumiChatSectionPlacement = LumiCoreLayout.LumiChatSectionPlacement
public typealias LumiChatSectionItem = LumiCoreLayout.LumiChatSectionItem
public typealias LumiChatSectionToolbarBarItem = LumiCoreLayout.LumiChatSectionToolbarBarItem
public typealias LumiChatSectionHeaderItem = LumiCoreLayout.LumiChatSectionHeaderItem
public typealias LumiChatSectionToolbarPlacement = LumiCoreLayout.LumiChatSectionToolbarPlacement
public typealias LumiChatSectionToolbarItem = LumiCoreLayout.LumiChatSectionToolbarItem

// MARK: - Split Divider Types

public typealias DividerClamp = LumiCoreLayout.DividerClamp
public typealias DividerDragClassification = LumiCoreLayout.DividerDragClassification
public typealias SplitDividerAccess = LumiCoreLayout.SplitDividerAccess
public typealias SplitDividerRole = LumiCoreLayout.SplitDividerRole

// 类型经 typealias 导出；`Notification.Name` / `View` 扩展无法 typealias，
// 需要 `@_exported` 让只 import LumiCoreKit 的下游模块（插件）继续可见，
// 与这些代码此前直接内嵌在 LumiCoreKit 时的可见性保持一致。
@_exported import LumiCoreProject

// MARK: - Project Component Types

public typealias ProjectComponent = LumiCoreProject.ProjectComponent
public typealias ProjectState = LumiCoreProject.ProjectState
public typealias ProjectEntry = LumiCoreProject.ProjectEntry
public typealias ProjectLanguageDetector = LumiCoreProject.ProjectLanguageDetector

@_exported import LumiCoreStorage

// MARK: - Storage Component Types

public typealias StorageComponent = LumiCoreStorage.StorageComponent

@_exported import LumiCoreMessage

// MARK: - Message Types

public typealias LumiChatMessageRole = LumiCoreMessage.LumiChatMessageRole
public typealias LumiPendingMessage = LumiCoreMessage.LumiPendingMessage
public typealias LumiChatMarkers = LumiCoreMessage.LumiChatMarkers
public typealias LumiMessagePerformanceMetadata = LumiCoreChat.LumiMessagePerformanceMetadata
public typealias LumiMessageTokenMetadata = LumiCoreChat.LumiMessageTokenMetadata
public typealias LumiToolTag = LumiCoreMessage.LumiToolTag

// MARK: - Turn Types
// LumiTurnEndReason 已下沉到 LumiCoreMessage（通过 @_exported import 导出）
// TurnDerivation 和 TurnOutcome 已合并到 LumiCoreChat

public typealias TurnDerivation = LumiCoreChat.TurnDerivation
public typealias TurnOutcome = LumiCoreChat.TurnOutcome

@_exported import LumiCoreAgentTool

// MARK: - Agent Tool Types

public typealias LumiAgentTool = LumiCoreAgentTool.LumiAgentTool
public typealias LumiAgentToolInfo = LumiCoreAgentTool.LumiAgentToolInfo
public typealias LumiToolCall = LumiCoreMessage.LumiToolCall
public typealias LumiToolResult = LumiCoreMessage.LumiToolResult
public typealias LumiToolServicing = LumiCoreAgentTool.LumiToolServicing
public typealias ToolService = LumiCoreAgentTool.ToolService

@_exported import LumiCoreChat

// MARK: - Chat Types

public typealias LumiChatMessage = LumiCoreMessage.LumiChatMessage
public typealias LumiChatServicing = LumiCoreChat.LumiChatServicing
public typealias LumiMessageRendererItem = LumiCoreMessage.LumiMessageRendererItem
public typealias InlineToolCallDetector = LumiCoreMessage.InlineToolCallDetector
public typealias ChatService = LumiCoreChat.ChatService
public typealias ChatServiceDelegate = LumiCoreChat.ChatServiceDelegate
public typealias ChatSectionCoordinator = LumiCoreChat.ChatSectionCoordinator
public typealias LumiConversationSummary = LumiCoreMessage.LumiConversationSummary
public typealias LumiImageAttachment = LumiCoreMessage.LumiImageAttachment
public typealias LumiPendingToolConfirmation = LumiCoreMessage.LumiPendingToolConfirmation
public typealias LumiSendMiddleware = LumiCoreMessage.LumiSendMiddleware
public typealias LumiStreamChunk = LumiCoreMessage.LumiStreamChunk
public typealias LumiSendContext = LumiCoreMessage.LumiSendContext
public typealias LumiConversationLanguage = LumiCoreMessage.LumiConversationLanguage
public typealias LumiAutomationLevel = LumiCoreMessage.LumiAutomationLevel
public typealias LumiResponseVerbosity = LumiCoreMessage.LumiResponseVerbosity
public typealias LumiModelRoutingMode = LumiCoreMessage.LumiModelRoutingMode
public typealias LumiLLMErrorDisposition = LumiCoreMessage.LumiLLMErrorDisposition
public typealias LumiLLMFailureDetail = LumiCoreMessage.LumiLLMFailureDetail

@_exported import LumiCoreLLMProvider

// MARK: - LLM Provider Types

public typealias LumiLLMProvider = LumiCoreLLMProvider.LumiLLMProvider
public typealias LumiLLMProviderInfo = LumiCoreMessage.LumiLLMProviderInfo
public typealias LumiLLMRequest = LumiCoreLLMProvider.LumiLLMRequest
public typealias LumiLLMProviderStatus = LumiCoreLLMProvider.LumiLLMProviderStatus
public typealias LumiProviderState = LumiCoreLLMProvider.LumiProviderState

// MARK: - Streaming Request Support

/// 流式请求支持工具（兼容旧命名）
public typealias LumiStreamingRequestSupport = StreamingRequestSupport

// MARK: - Provider Error Support

/// 错误消息生成工具（兼容旧命名）
public typealias LumiLLMProviderErrorSupport = ProviderErrorSupport

@_exported import LumiCorePlugin

// MARK: - Plugin Types
// LumiCoreAccessing 现在定义在 LumiCorePlugin 中，LumiCoreKit 通过 @_exported 自动导出

// MARK: - Plugin Types Aliases

public typealias LumiPlugin = LumiCorePlugin.LumiPlugin
public typealias LumiPluginInfo = LumiCorePlugin.LumiPluginInfo
public typealias LumiPluginContributionFailure = LumiCorePlugin.LumiPluginContributionFailure
public typealias AgentToolProviding = LumiCorePlugin.AgentToolProviding
public typealias LumiStatusBarItem = LumiCorePlugin.LumiStatusBarItem
public typealias LumiTitleToolbarItem = LumiCorePlugin.LumiTitleToolbarItem
public typealias LumiViewContainerItem = LumiCorePlugin.LumiViewContainerItem

@_exported import LumiCoreSubAgent

// MARK: - SubAgent Types

public typealias SubAgentDelegateTool = LumiCoreSubAgent.SubAgentDelegateTool
public typealias LumiSubAgentDefinition = LumiCoreSubAgent.LumiSubAgentDefinition

@_exported import LumiCoreMenuBar

// MARK: - MenuBar Types

public typealias LumiMenuBarContentItem = LumiCoreMenuBar.LumiMenuBarContentItem
public typealias LumiMenuBarPopupItem = LumiCoreMenuBar.LumiMenuBarPopupItem

@_exported import LumiCoreOverlay

// MARK: - Overlay Types

// Add type aliases as needed

@_exported import LumiCorePanelChrome

// MARK: - PanelChrome Types

// Add type aliases as needed