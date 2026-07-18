import Foundation
import LumiComponentGit
import LumiComponentLayout

// MARK: - Git Component Types

public typealias GitComponent = LumiComponentGit.GitComponent
public typealias GitAccessCoordinator = LumiComponentGit.GitAccessCoordinator

// MARK: - Layout Component Types

public typealias LayoutComponent = LumiComponentLayout.LayoutComponent
public typealias LayoutState = LumiComponentLayout.LayoutState
public typealias LayoutEventPayload = LumiComponentLayout.LayoutEventPayload

// MARK: - Logo Component Types

public typealias LogoComponent = LumiComponentLayout.LogoComponent
public typealias LogoItem = LumiComponentLayout.LogoItem
public typealias LogoScene = LumiComponentLayout.LogoScene

// MARK: - Chat Section Types

public typealias LumiChatSectionLayout = LumiComponentLayout.LumiChatSectionLayout
public typealias LumiChatSectionPlacement = LumiComponentLayout.LumiChatSectionPlacement
public typealias LumiChatSectionItem = LumiComponentLayout.LumiChatSectionItem
public typealias LumiChatSectionToolbarBarItem = LumiComponentLayout.LumiChatSectionToolbarBarItem
public typealias LumiChatSectionHeaderItem = LumiComponentLayout.LumiChatSectionHeaderItem
public typealias LumiChatSectionToolbarPlacement = LumiComponentLayout.LumiChatSectionToolbarPlacement
public typealias LumiChatSectionToolbarItem = LumiComponentLayout.LumiChatSectionToolbarItem

// MARK: - Split Divider Types

public typealias DividerClamp = LumiComponentLayout.DividerClamp
public typealias DividerDragClassification = LumiComponentLayout.DividerDragClassification
public typealias SplitDividerAccess = LumiComponentLayout.SplitDividerAccess
public typealias SplitDividerRole = LumiComponentLayout.SplitDividerRole

// 类型经 typealias 导出；`Notification.Name` / `View` 扩展无法 typealias，
// 需要 `@_exported` 让只 import LumiCoreKit 的下游模块（插件）继续可见，
// 与这些代码此前直接内嵌在 LumiCoreKit 时的可见性保持一致。
@_exported import LumiComponentProject

// MARK: - Project Component Types

public typealias ProjectComponent = LumiComponentProject.ProjectComponent
public typealias ProjectState = LumiComponentProject.ProjectState
public typealias ProjectEntry = LumiComponentProject.ProjectEntry
public typealias ProjectLanguageDetector = LumiComponentProject.ProjectLanguageDetector

@_exported import LumiComponentStorage

// MARK: - Storage Component Types

public typealias StorageComponent = LumiComponentStorage.StorageComponent

@_exported import LumiComponentMessage

// MARK: - Message Types

public typealias LumiChatMessageRole = LumiComponentMessage.LumiChatMessageRole
public typealias LumiPendingMessage = LumiComponentMessage.LumiPendingMessage
public typealias LumiChatMarkers = LumiComponentMessage.LumiChatMarkers
public typealias LumiMessagePerformanceMetadata = LumiComponentChat.LumiMessagePerformanceMetadata
public typealias LumiMessageTokenMetadata = LumiComponentChat.LumiMessageTokenMetadata
public typealias LumiToolTag = LumiComponentMessage.LumiToolTag

@_exported import LumiComponentTurn

// MARK: - Turn Types

public typealias TurnDerivation = LumiComponentTurn.TurnDerivation
public typealias TurnOutcome = LumiComponentTurn.TurnOutcome
public typealias LumiTurnEndReason = LumiComponentTurn.LumiTurnEndReason

@_exported import LumiComponentAgentTool

// MARK: - Agent Tool Types

public typealias LumiAgentTool = LumiComponentAgentTool.LumiAgentTool
public typealias LumiAgentToolInfo = LumiComponentAgentTool.LumiAgentToolInfo
public typealias LumiToolCall = LumiComponentMessage.LumiToolCall
public typealias LumiToolResult = LumiComponentMessage.LumiToolResult
public typealias LumiToolServicing = LumiComponentAgentTool.LumiToolServicing
public typealias ToolService = LumiComponentAgentTool.ToolService

@_exported import LumiComponentChat

// MARK: - Chat Types

public typealias LumiChatMessage = LumiComponentMessage.LumiChatMessage
public typealias LumiChatServicing = LumiComponentChat.LumiChatServicing
public typealias LumiMessageRendererItem = LumiComponentMessage.LumiMessageRendererItem
public typealias InlineToolCallDetector = LumiComponentMessage.InlineToolCallDetector
public typealias ChatService = LumiComponentChat.ChatService
public typealias ChatServiceDelegate = LumiComponentChat.ChatServiceDelegate
public typealias ChatSectionCoordinator = LumiComponentChat.ChatSectionCoordinator
public typealias LumiConversationSummary = LumiComponentMessage.LumiConversationSummary
public typealias LumiImageAttachment = LumiComponentMessage.LumiImageAttachment
public typealias LumiPendingToolConfirmation = LumiComponentMessage.LumiPendingToolConfirmation
public typealias LumiSendMiddleware = LumiComponentMessage.LumiSendMiddleware
public typealias LumiStreamChunk = LumiComponentMessage.LumiStreamChunk
public typealias LumiSendContext = LumiComponentMessage.LumiSendContext
public typealias LumiConversationLanguage = LumiComponentMessage.LumiConversationLanguage
public typealias LumiAutomationLevel = LumiComponentMessage.LumiAutomationLevel
public typealias LumiResponseVerbosity = LumiComponentMessage.LumiResponseVerbosity
public typealias LumiModelRoutingMode = LumiComponentMessage.LumiModelRoutingMode
public typealias LumiLLMErrorDisposition = LumiComponentMessage.LumiLLMErrorDisposition
public typealias LumiLLMFailureDetail = LumiComponentMessage.LumiLLMFailureDetail

@_exported import LumiComponentLLMProvider

// MARK: - LLM Provider Types

public typealias LumiLLMProvider = LumiComponentLLMProvider.LumiLLMProvider
public typealias LumiLLMProviderInfo = LumiComponentMessage.LumiLLMProviderInfo
public typealias LumiLLMRequest = LumiComponentLLMProvider.LumiLLMRequest
public typealias LumiLLMProviderStatus = LumiComponentLLMProvider.LumiLLMProviderStatus
public typealias LumiProviderState = LumiComponentLLMProvider.LumiProviderState

@_exported import LumiComponentPlugin

// MARK: - Plugin Types

public typealias LumiPlugin = LumiComponentPlugin.LumiPlugin
public typealias LumiPluginInfo = LumiComponentPlugin.LumiPluginInfo
public typealias LumiPluginContext = LumiComponentPlugin.LumiPluginContext
public typealias LumiPluginDependencies = LumiComponentPlugin.LumiPluginDependencies
public typealias LumiPluginContributionFailure = LumiComponentPlugin.LumiPluginContributionFailure
public typealias AgentToolProviding = LumiComponentPlugin.AgentToolProviding
public typealias LumiStatusBarItem = LumiComponentPlugin.LumiStatusBarItem
public typealias LumiTitleToolbarItem = LumiComponentPlugin.LumiTitleToolbarItem
public typealias LumiViewContainerItem = LumiComponentPlugin.LumiViewContainerItem

@_exported import LumiComponentSubAgent

// MARK: - SubAgent Types

public typealias SubAgentDelegateTool = LumiComponentSubAgent.SubAgentDelegateTool
public typealias LumiSubAgentDefinition = LumiComponentSubAgent.LumiSubAgentDefinition

@_exported import LumiComponentMenuBar

// MARK: - MenuBar Types

public typealias LumiMenuBarContentItem = LumiComponentMenuBar.LumiMenuBarContentItem
public typealias LumiMenuBarPopupItem = LumiComponentMenuBar.LumiMenuBarPopupItem

@_exported import LumiComponentOverlay

// MARK: - Overlay Types

// Add type aliases as needed

@_exported import LumiComponentPanelChrome

// MARK: - PanelChrome Types

// Add type aliases as needed