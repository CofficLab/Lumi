import Combine
import Foundation

import LumiCoreLayout

import LumiCoreMenuBar

import LumiCoreOverlay
import LumiCorePanelChrome
import LumiCoreProject
import LumiCoreStorage

import LumiUI
import SwiftUI

/// Lumi lightweight core
///
/// Architecture principle: Kernel 只持有各类能力（Provider），不进行能力转发。
/// 错误示例: kernel.getMessageList() — 这会让 Kernel 无限膨胀
/// 正确示例: kernel.messageManager.getMessageList() — 能力委托给具体 Provider
///
/// Only holds protocol types, does not depend on concrete implementations.
/// All concrete implementations are injected via plugins.
@MainActor
public final class LumiKernelContainer: ObservableObject {
    // MARK: - Service Registry

    /// Service registry
    private var services: [ObjectIdentifier: Any] = [:]

    /// Service change subscriptions
    private var serviceSubscriptions: [ObjectIdentifier: AnyCancellable] = [:]

    // MARK: - Service Accessors (Protocol Types)

    /// Plugin management service
    public var plugin: (any PluginProviding)? {
        resolveService(PluginProviding.self)
    }

    /// LumiCore service (storage, project, layout, logo, agentTool, chat, editor)
    public var lumiCore: (any LumiCoreProviding)? {
        resolveService(LumiCoreProviding.self)
    }

    /// Storage service
    public var storage: (any StorageProviding)? {
        resolveService(StorageProviding.self)
    }

    /// Project management service
    public var project: (any ProjectProviding)? {
        resolveService(ProjectProviding.self)
    }

    /// Layout service
    public var layout: (any LayoutProviding)? {
        resolveService(LayoutProviding.self)
    }

    /// View container service
    public var viewContainer: (any ViewContainerProviding)? {
        resolveService(ViewContainerProviding.self)
    }

    /// Command menu service
    public var command: (any CommandProviding)? {
        resolveService(CommandProviding.self)
    }

    /// Menu bar service
    public var menuBar: (any MenuBarProviding)? {
        resolveService(MenuBarProviding.self)
    }

    /// Title toolbar service
    public var toolbarProvider: (any TitleToolbarProviding)? {
        resolveService(TitleToolbarProviding.self)
    }

    /// Send middleware service
    public var sendMiddleware: (any SendMiddlewareProviding)? {
        resolveService(SendMiddlewareProviding.self)
    }

    /// Chat service
    public var chat: (any ChatServiceProviding)? {
        resolveService(ChatServiceProviding.self)
    }

    /// Message send service (user input → persist + dispatch)
    public var messageSend: (any MessageSendManaging)? {
        resolveService(MessageSendManaging.self)
    }

    /// Conversation management service
    public var conversations: (any ConversationManaging)? {
        resolveService(ConversationManaging.self)
    }

    /// Message management service
    public var messageManager: (any MessageManaging)? {
        resolveService(MessageManaging.self)
    }

    /// Chat section service
    public var chatSection: (any ChatSectionProviding)? {
        resolveService(ChatSectionProviding.self)
    }

    /// Editor service
    public var editor: (any EditorServiceProviding)? {
        resolveService(EditorServiceProviding.self)
    }

    /// Agent tool service
    public var agentTool: (any AgentToolProviding)? {
        resolveService(AgentToolProviding.self)
    }

    /// LLM Provider service
    public var llmProvider: (any LLMProviderManaging)? {
        resolveService(LLMProviderManaging.self)
    }

    /// Chat contribution service (middlewares, renderers, turn hooks)
    public var chatContribution: (any ChatContributionProviding)? {
        resolveService(ChatContributionProviding.self)
    }

    /// Panel service
    public var panel: (any PanelProviding)? {
        resolveService(PanelProviding.self)
    }

    /// Status bar service
    public var statusBar: (any StatusBarProviding)? {
        resolveService(StatusBarProviding.self)
    }

    /// Settings service
    public var settings: (any SettingsProviding)? {
        resolveService(SettingsProviding.self)
    }

    /// Logo service
    public var logo: (any LogoProviding)? {
        resolveService(LogoProviding.self)
    }

    /// Theme service
    public var theme: (any LumiThemeServicing)? {
        resolveService(LumiThemeServicing.self)
    }

    /// Onboarding service
    public var onboarding: (any OnboardingProviding)? {
        resolveService(OnboardingProviding.self)
    }

    /// Message renderer management service
    public var messageRendererManager: (any MessageRendererManaging)? {
        resolveService(MessageRendererManaging.self)
    }

    /// Workspace state service (controls rail/chat/content/activityBar visibility)
    public var workspaceState: (any WorkspaceStateProviding)? {
        resolveService(WorkspaceStateProviding.self)
    }

    // MARK: - Initialization

    public init() {
        // Lightweight initialization, no concrete implementations created
    }

    // MARK: - Generic Service Registry

    /// Register service implementation
    public func registerService<T>(_ type: T.Type, _ instance: T) {
        services[ObjectIdentifier(type)] = instance

        // Forward objectWillChange from ObservableObject services
        subscribeToObjectWillChange(observable: instance, key: ObjectIdentifier(type))
    }

    /// Helper to subscribe to ObservableObject's objectWillChange
    private func subscribeToObjectWillChange<T>(observable: T, key: ObjectIdentifier) {
        guard let observableObject = observable as? any ObservableObject else { return }

        // Force cast to ObservableObjectPublisher which is the concrete type
        let publisher = observableObject.objectWillChange as! ObservableObjectPublisher
        serviceSubscriptions[key] = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
            }
    }

    /// Resolve service implementation
    public func resolveService<T>(_ type: T.Type = T.self) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    /// Unregister service
    public func unregisterService<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        services.removeValue(forKey: key)
        serviceSubscriptions.removeValue(forKey: key)
    }

    // MARK: - Service Registration

    /// Register plugin management service
    public func registerPluginService(_ plugin: any PluginProviding) {
        registerService(PluginProviding.self, plugin)
    }

    /// Register LumiCore service
    public func registerLumiCore(_ core: any LumiCoreProviding) {
        registerService(LumiCoreProviding.self, core)
    }

    /// Register storage service
    public func registerStorage(_ storage: any StorageProviding) {
        registerService(StorageProviding.self, storage)
    }

    /// Register project management service
    public func registerProject(_ project: any ProjectProviding) {
        registerService(ProjectProviding.self, project)
    }

    /// Register layout service
    public func registerLayout(_ layout: any LayoutProviding) {
        registerService(LayoutProviding.self, layout)
    }

    /// Register view container service
    public func registerViewContainerService(_ service: any ViewContainerProviding) {
        registerService(ViewContainerProviding.self, service)
    }

    /// Register command service
    public func registerCommandService(_ command: any CommandProviding) {
        registerService(CommandProviding.self, command)
    }

    /// Register menu bar service
    public func registerMenuBarService(_ menuBar: any MenuBarProviding) {
        registerService(MenuBarProviding.self, menuBar)
    }

    /// Register title toolbar service
    public func registerTitleToolbarService(_ titleToolbar: any TitleToolbarProviding) {
        registerService(TitleToolbarProviding.self, titleToolbar)
    }

    /// Register send middleware service
    public func registerSendMiddlewareService(_ sendMiddleware: any SendMiddlewareProviding) {
        registerService(SendMiddlewareProviding.self, sendMiddleware)
    }

    /// Register chat service
    public func registerChat(_ chat: any ChatServiceProviding) {
        registerService(ChatServiceProviding.self, chat)
    }

    /// Register message send service
    public func registerMessageSend(_ messageSend: any MessageSendManaging) {
        registerService(MessageSendManaging.self, messageSend)
    }

    /// Register conversation managing service
    public func registerConversations(_ conversations: any ConversationManaging) {
        registerService(ConversationManaging.self, conversations)
    }

    /// Register message managing service
    public func registerMessageManager(_ messageManager: any MessageManaging) {
        registerService(MessageManaging.self, messageManager)
    }

    /// Register chat section service
    public func registerChatSectionService(_ chatSection: any ChatSectionProviding) {
        registerService(ChatSectionProviding.self, chatSection)
    }

    /// Register editor service
    public func registerEditor(_ editor: any EditorServiceProviding) {
        registerService(EditorServiceProviding.self, editor)
    }

    /// Register agent tool service
    public func registerAgentToolService(_ agentTool: any AgentToolProviding) {
        registerService(AgentToolProviding.self, agentTool)
    }

    /// Register LLM Provider service
    public func registerLLMProviderService(_ llmProvider: any LLMProviderManaging) {
        registerService(LLMProviderManaging.self, llmProvider)
    }

    /// Register Chat contribution service
    public func registerChatContributionService(_ chatContribution: any ChatContributionProviding) {
        registerService(ChatContributionProviding.self, chatContribution)
    }

    /// Register panel service
    public func registerPanelService(_ panel: any PanelProviding) {
        registerService(PanelProviding.self, panel)
    }

    /// Register status bar service
    public func registerStatusBarService(_ statusBar: any StatusBarProviding) {
        registerService(StatusBarProviding.self, statusBar)
    }

    /// Register settings service
    public func registerSettingsService(_ settings: any SettingsProviding) {
        registerService(SettingsProviding.self, settings)
    }

    /// Register logo service
    public func registerLogoService(_ logo: any LogoProviding) {
        registerService(LogoProviding.self, logo)
    }

    /// Register theme service
    public func registerThemeService(_ theme: any LumiThemeServicing) {
        registerService(LumiThemeServicing.self, theme)
    }

    /// Register onboarding service
    public func registerOnboardingService(_ onboarding: any OnboardingProviding) {
        registerService(OnboardingProviding.self, onboarding)
    }

    /// Register message renderer management service
    public func registerMessageRendererManagerService(_ manager: any MessageRendererManaging) {
        registerService(MessageRendererManaging.self, manager)
    }

    /// Register workspace state service
    public func registerWorkspaceStateService(_ state: any WorkspaceStateProviding) {
        registerService(WorkspaceStateProviding.self, state)
    }

    // MARK: - Startup & Validation

    /// Startup kernel and perform self-check
    ///
    /// Checks if all required services are registered, throws error if requirements not met.
    /// - Throws: If required services are missing
    public func startup() throws {
        var missingServices: [String] = []

        if storage == nil { missingServices.append("Storage") }
        if project == nil { missingServices.append("Project") }
        if layout == nil { missingServices.append("Layout") }
        if viewContainer == nil { missingServices.append("ViewContainer") }
        if command == nil { missingServices.append("Command") }
        if menuBar == nil { missingServices.append("MenuBar") }
        if toolbarProvider == nil { missingServices.append("TitleToolbar") }
        if sendMiddleware == nil { missingServices.append("SendMiddleware") }
        if chat == nil { missingServices.append("Chat") }
        if messageSend == nil { missingServices.append("MessageSend") }
        if llmProvider == nil { missingServices.append("LLMProvider") }
        if chatSection == nil { missingServices.append("ChatSection") }
        if editor == nil { missingServices.append("Editor") }
        if agentTool == nil { missingServices.append("AgentTool") }
        if panel == nil { missingServices.append("Panel") }
        if statusBar == nil { missingServices.append("StatusBar") }
        if settings == nil { missingServices.append("Settings") }
        if logo == nil { missingServices.append("Logo") }
        if theme == nil { missingServices.append("Theme") }
        if plugin == nil { missingServices.append("Plugin") }
        if messageRendererManager == nil { missingServices.append("MessageRendererManager") }
        if workspaceState == nil { missingServices.append("WorkspaceState") }

        if !missingServices.isEmpty {
            throw LumiKernelError.missingRequiredServices(missingServices)
        }
    }
}

/// 兼容旧代码: 用 LumiKernel 实例化时,使用 LumiKernelContainer。
public typealias LumiKernel = LumiKernelContainer

