import Combine
import Foundation
import MagicAlert
import SwiftData
import SwiftUI
import LumiCoreKit
import AgentToolKit

/// 根视图容器组件
/// 为应用提供统一的上下文环境，管理核心服务初始化和环境注入
///
/// ## 架构说明
///
/// 全局共享 VM 通过 `RootContainer.shared` 注入。
/// 窗口级 VM 通过 `WindowContainer` 注入，每个窗口拥有独立的 VM 实例。
///
/// ## 使用方式
///
/// ```swift
/// ContentLayout()
///     .inRootView(container: windowContainer)
/// ```
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// 窗口容器（每窗口独立）
    @ObservedObject var windowContainer: WindowContainer

    /// 全局服务容器（单例）。
    @StateObject var container = RootContainer.shared
    @StateObject private var pluginProjectContext = PluginProjectContext()
    @StateObject private var pluginRecentProjectsVM = LumiCoreKit.AppProjectsVM()
    @StateObject private var pluginThemeVM = LumiCoreKit.AppThemeVM()
    @StateObject private var pluginEditorContext = LumiCoreKit.EditorContext()
    @StateObject private var pluginPluginVM = LumiCoreKit.AppPluginVM()
    @StateObject private var pluginLLMVM = LumiCoreKit.AppLLMVM()
    @StateObject private var pluginGitVM = LumiCoreKit.AppGitVM()
    @StateObject private var pluginConversationVM = LumiCoreKit.WindowConversationVM()
    @StateObject private var pluginConversationListContext = LumiCoreKit.ConversationListContext()
    @StateObject private var pluginLayoutContext = LumiCoreKit.WindowLayoutVM()

    init(container: WindowContainer, @ViewBuilder content: () -> Content) {
        self._windowContainer = ObservedObject(wrappedValue: container)
        self.content = content()
    }

    var body: some View {
        pluginLayoutLifecycleScene
    }

    private var baseScene: some View {
        ZStack {
            RootListener(scope: windowContainer)
            configuredContent
        }
        .onFileDroppedToChat(windowId: windowContainer.id) { url in
            handleFileDroppedToChat(url)
        }
        .onOpenFileInEditor(windowId: windowContainer.id) { url in
            handleOpenFileInEditor(url)
        }
        .onDisappear {
            windowContainer.persistCurrentStateSynchronously()
            windowContainer.cleanup()
            container.toolService.clearConversationListContext(for: windowContainer.id)
        }
    }

    private var initialLifecycleScene: some View {
        baseScene
            .onAppear(perform: performInitialLifecycleSetup)
    }

    private var projectLifecycleScene: some View {
        initialLifecycleScene
        .onChange(of: windowContainer.projectVM.currentProjectPath) { _, _ in
            syncPluginProjectContext()
        }
        .onChange(of: windowContainer.projectVM.languagePreference) { _, _ in
            syncPluginProjectContext()
        }
        .onChange(of: container.recentProjectsVM.recentProjects) { _, _ in
            syncPluginRecentProjectsContext()
        }
        .onChange(of: windowContainer.conversationVM.selectedConversationId) { _, _ in
            restoreSelectedConversationLanguagePreference()
            syncPluginConversationListContext()
        }
        .onChange(of: windowContainer.projectVM.currentProjectPath) { _, _ in
            syncPluginConversationListContext()
        }
        .onChange(of: windowContainer.projectVM.currentProjectName) { _, _ in
            syncPluginConversationListContext()
        }
        .onReceive(windowContainer.editorVM.service.state.$currentFileURL) { _ in
            syncEditorContextFileURL()
        }
        .onChange(of: windowContainer.conversationVM.selectedConversationId) { _, _ in
            syncPluginConversationContext()
        }
        .onChange(of: windowContainer.chatDraftVM.text) { _, _ in
            syncPluginConversationContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { _ in
            syncPluginConversationContext()
            pluginConversationVM.notifyPendingMessagesChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTurnPhaseChanged)) { _ in
            syncPluginConversationContext()
            pluginConversationVM.notifyPendingMessagesChanged()
        }
        .onChange(of: windowContainer.agentAttachmentsVM.pendingAttachments) { _, _ in
            syncPluginConversationContext()
            pluginConversationVM.notifyAttachmentsChanged()
        }
        .onReceive(windowContainer.commandSuggestionVM.objectWillChange) { _ in
            pluginConversationVM.notifyCommandSuggestionsChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: .conversationDidChange)) { notification in
            syncPluginConversationListContext()
            guard let change = Self.conversationListChange(from: notification) else { return }
            pluginConversationListContext.notifyConversationChanged(change)
        }
        .onReceive(windowContainer.conversationSendStatusVM.$statusMessageByConversationId) { _ in
            pluginConversationVM.notifyStatusChanged()
            pluginConversationListContext.notifyConversationStatusChanged()
        }
    }

    private var llmLifecycleScene: some View {
        projectLifecycleScene
        .onChange(of: container.agentSessionConfig.selectedProviderId) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.currentModel) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.isAutoMode) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.chatMode) { _, _ in syncPluginLLMContext() }
        .onChange(of: container.agentSessionConfig.verbosity) { _, _ in syncPluginLLMContext() }
    }

    private var appLayoutLifecycleScene: some View {
        llmLifecycleScene
        .onChange(of: windowContainer.layoutVM.bottomPanelVisible) { _, _ in syncLayoutContext() }
        .onChange(of: windowContainer.layoutVM.contentPanelVisible) { _, _ in syncLayoutContext() }
        .onChange(of: windowContainer.layoutVM.editorVisible) { _, _ in syncLayoutContext() }
        .onChange(of: windowContainer.layoutVM.railVisible) { _, _ in syncLayoutContext() }
        .onChange(of: windowContainer.layoutVM.rightSidebarVisible) { _, _ in syncLayoutContext() }
        .onChange(of: windowContainer.layoutVM.activeViewContainerIcon) { _, _ in syncLayoutContext() }
        .onChange(of: windowContainer.layoutVM.selectedAgentSidebarTabId) { _, _ in syncLayoutContext() }
        .onChange(of: windowContainer.layoutVM.selectedAgentDetailId) { _, _ in syncLayoutContext() }
        .onChange(of: windowContainer.layoutVM.layoutRatios) { _, _ in syncLayoutContext() }
    }

    private var pluginLayoutLifecycleScene: some View {
        appLayoutLifecycleScene
        .onChange(of: pluginLayoutContext.bottomPanelVisible) { _, _ in applyLayoutContextToWindow() }
        .onChange(of: pluginLayoutContext.contentPanelVisible) { _, _ in applyLayoutContextToWindow() }
        .onChange(of: pluginLayoutContext.editorVisible) { _, _ in applyLayoutContextToWindow() }
        .onChange(of: pluginLayoutContext.railVisible) { _, _ in applyLayoutContextToWindow() }
        .onChange(of: pluginLayoutContext.rightSidebarVisible) { _, _ in applyLayoutContextToWindow() }
        .onChange(of: pluginLayoutContext.activeViewContainerIcon) { _, _ in applyLayoutContextToWindow() }
        .onChange(of: pluginLayoutContext.selectedAgentSidebarTabId) { _, _ in applyLayoutContextToWindow() }
        .onChange(of: pluginLayoutContext.selectedAgentDetailId) { _, _ in applyLayoutContextToWindow() }
        .onChange(of: pluginLayoutContext.layoutRatios) { _, _ in applyLayoutContextToWindow() }
    }

    private var configuredContent: some View {
        windowEnvironmentContent
            .environment(\.windowContainer, windowContainer)
            .modelContainer(container.modelContainer)
    }

    private var windowEnvironmentContent: some View {
        globalEnvironmentContent
            // 窗口级 VM（每窗口独立）
            .environmentObject(windowContainer)
            .environmentObject(windowContainer.editorVM)
            .environmentObject(windowContainer.editorVM.service)
            .environmentObject(windowContainer.conversationVM)
            .environmentObject(pluginConversationVM)
            .environmentObject(pluginConversationListContext)
            .environmentObject(windowContainer.projectVM)
            .environmentObject(pluginProjectContext)
            .environmentObject(windowContainer.layoutVM)
            .environmentObject(pluginLayoutContext)
            .environmentObject(windowContainer.agentAttachmentsVM)
            .environmentObject(windowContainer.inputQueueVM)
            .environmentObject(windowContainer.chatDraftVM)
            .environmentObject(windowContainer.permissionHandlingVM)
            .environmentObject(windowContainer.commandSuggestionVM)
            .environmentObject(windowContainer.permissionRequestVM)
            .environmentObject(windowContainer.taskCancellationVM)
            .environmentObject(windowContainer.conversationSendStatusVM)
            .environmentObject(windowContainer.projectContextRequestVM)
            .alert(
                "无法创建对话",
                isPresented: Binding(
                    get: { windowContainer.conversationVM.conversationCreationError != nil },
                    set: { isPresented in
                        if !isPresented {
                            windowContainer.conversationVM.clearConversationCreationError()
                        }
                    }
                )
            ) {
                Button("确定") {
                    windowContainer.conversationVM.clearConversationCreationError()
                }
            } message: {
                Text(windowContainer.conversationVM.conversationCreationError ?? "")
            }
    }

    private var globalEnvironmentContent: some View {
        content
            .withMagicToast()
            // 全局 VM（所有窗口共享）
            .environmentObject(container.windowManagerVM)
            .environmentObject(container.themeVM)
            .environmentObject(pluginThemeVM)
            .environmentObject(pluginEditorContext)
            .environmentObject(container.providerRegistry)
            .environmentObject(container.pluginVM)
            .environmentObject(pluginPluginVM)
            .environmentObject(container.messageRendererVM)
            .environmentObject(container.conversationTurnServices)
            .environmentObject(container.agentSessionConfig)
            .environmentObject(pluginLLMVM)
            .environmentObject(container.chatHistoryVM)
            .environmentObject(container.recentProjectsVM)
            .environmentObject(pluginRecentProjectsVM)
            .environmentObject(container.gitVM)
            .environmentObject(pluginGitVM)
            .environmentObject(container.idleTimeVM)
    }

    private func performInitialLifecycleSetup() {
        restoreSelectedConversationLanguagePreference()
        syncPluginProjectContext()
        syncPluginRecentProjectsContext()
        syncPluginConversationContext()
        syncPluginConversationListContext()
        syncPluginLLMContext()
        syncLayoutContext()
        configureDefaultIconProvider()
        configurePluginRuntimeContext()
        configureProjectContextActions()
        configureConversationListContext()
        configureProjectConversationContext()
        configureEditorContextActions()
    }

    /// 设置首次回退图标提供者，供布局持久化恢复时使用
    private func configureDefaultIconProvider() {
        let pluginVM = container.pluginVM
        pluginLayoutContext.defaultIconProvider = { [pluginVM] in
            pluginVM.getViewContainerItems().first?.icon
        }
    }

    private func configurePluginRuntimeContext() {
        container.conversationTurnServices.setRootContainer(container)
        let agentConversationStore = LiveAgentConversationStore(
            messageService: container.messageService,
            conversationService: container.conversationService
        )
        container.pluginVM.configureRuntime(context: PluginRuntimeContext(
            editorServiceProvider: { [container, windowContainer] context in
                Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                    .editorVM.service
            },
            openFile: { [container, windowContainer] url, projectRoot, context in
                let targetWindow = Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                if let projectRoot {
                    await targetWindow.editorVM.service.refreshProjectContext(for: projectRoot)
                }
                targetWindow.editorVM.service.open(at: url)
            },
            openFilePath: { [container, windowContainer] path, windowId in
                let targetWindow = windowId.flatMap { container.windowManagerVM.getContainer($0) }
                    ?? Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
                targetWindow.editorVM.service.open(at: URL(fileURLWithPath: path))
            },
            currentProjectPath: { [container, windowContainer] context in
                let path = Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                    .projectVM.currentProjectPath
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return path.isEmpty ? nil : path
            },
            activeWindowId: { [container] in
                container.windowManagerVM.activeWindowId
            },
            editorThemeId: { [container] in
                container.themeVM.activeEditorThemeId
            },
            showsAssistantHeader: { [container] in
                container.agentSessionConfig.verbosity == .detailed
            },
            registerEditorTextInputInstaller: { installer in
                EditorSettingsLifecycle.registerMultiCursorTextView = { textView, state in
                    installer(textView, state)
                }
            },
            applyEditorFontName: { [container, windowContainer] fontName, context in
                Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                    .editorVM.service.state.fontName = fontName
            },
            databaseDirectory: {
                AppConfig.getDBFolderURL()
            },
            enqueueUserMessage: { message, turnContext in
                guard let appContext = turnContext as? AppTurnFinishedContext else { return }
                var pending = message
                pending.queueStatus = .pending
                appContext.conversationVM.saveMessage(pending, to: appContext.conversationId)
            },
            addToChat: { text, context in
                NotificationCenter.postAddToChat(text: text, windowId: context.windowId)
            },
            selectConversation: { [container, windowContainer] conversationId, context in
                Self.targetWindowContainer(for: context, fallback: windowContainer, rootContainer: container)
                    .switchToConversation(conversationId, reason: "pluginRuntime")
            },
            registerIdleTimeSnapshotProvider: { provider in
                Task {
                    await IdleTimeSnapshotProvider.shared.register(provider)
                    await MainActor.run {
                        NotificationCenter.default.post(name: .idleTimeSnapshotDidChange, object: nil)
                    }
                }
            },
            resumeToolCall: { [container, windowContainer] conversationIdStr, toolCallId, answer in
                guard let conversationId = UUID(uuidString: conversationIdStr) else { return }
                let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
                container.conversationTurnServices.resumeAwaitingToolCall(
                    conversationId: conversationId,
                    toolCallId: toolCallId,
                    answer: answer,
                    conversationVM: targetWindow.conversationVM
                )
            },
            agentConversationStore: agentConversationStore,
            saveMessage: { message, conversationId in
                agentConversationStore.saveMessage(message, conversationId: conversationId)
            },
            updateMessage: { [container] message, conversationId in
                _ = container.chatHistoryService.updateMessage(message, conversationId: conversationId)
            },
            loadMessages: { conversationId in
                agentConversationStore.loadMessages(for: conversationId)
            },
            loadTurnPhase: { conversationId in
                agentConversationStore.loadTurnPhase(for: conversationId)
            },
            setTurnPhase: { phase, conversationId in
                agentConversationStore.setTurnPhase(phase, conversationId: conversationId)
            },
            tryAcquireConversationLock: { conversationId in
                AgentConversationLock.shared.tryAcquire(conversationId)
            },
            releaseConversationLock: { conversationId in
                AgentConversationLock.shared.release(conversationId)
            },
            isConversationCancelled: { conversationId in
                AgentConversationLock.shared.isCancelled(conversationId)
            },
            markConversationCancelled: { conversationId in
                AgentConversationLock.shared.markCancelled(conversationId)
            },
            clearConversationCancelled: { conversationId in
                AgentConversationLock.shared.clearCancelled(conversationId)
            },
            prepareMessagesForLLM: { [container, windowContainer] conversationId, messages in
                let runtime = AgentLLMRuntime(container: container, windowContainer: windowContainer)
                return runtime.prepareMessages(conversationId: conversationId, messages: messages)
            },
            llmSendService: {
                let runtime = AgentLLMRuntime(container: container, windowContainer: windowContainer)
                return runtime.makeLLMSendService()
            }(),
            consumeTransientSystemPrompts: { conversationId in
                AgentTransientPromptStore.shared.consume(for: conversationId)
            },
            presentToolPermissionIfNeeded: { [container, windowContainer] message, conversationId async in
                await windowContainer.toolCallExecutor.presentPermissionIfNeeded(
                    assistantMessage: message,
                    conversationId: conversationId
                )
            },
            executeToolCalls: { [container, windowContainer] message, conversationId async in
                let summary = await windowContainer.toolCallExecutor.executeAll(
                    assistantMessage: message,
                    conversationId: conversationId
                )
                return ToolExecutionSummary(
                    hadUserRejection: summary.hadUserRejection,
                    hasAwaitingUserResponse: summary.hasAwaitingUserResponse
                )
            },
            finishAgentTurn: { [container, windowContainer] conversationId, endReason in
                AgentTurnFinisher(container: container, windowContainer: windowContainer)
                    .finish(conversationId: conversationId, endReason: endReason)
            },
            setConversationStatus: { [container, windowContainer] conversationId, content in
                windowContainer.conversationSendStatusVM.setStatus(
                    conversationId: conversationId,
                    content: content
                )
            },
            dequeueNextPendingMessage: { [container] conversationId in
                container.chatHistoryService.dequeueNextPendingMessage(forConversationId: conversationId)
            },
            runSendPreparePipeline: { [container, windowContainer] conversationId, message in
                await AgentSendPrepareRuntime.runPreparePipeline(
                    conversationId: conversationId,
                    message: message,
                    container: container,
                    windowContainer: windowContainer
                )
            },
            storeTransientSystemPrompts: { prompts, conversationId in
                AgentTransientPromptStore.shared.store(prompts, for: conversationId)
            },
            pendingMessages: { [container] conversationId in
                container.chatHistoryService.pendingMessages(forConversationId: conversationId)
            },
            removePendingMessage: { [container] messageId, conversationId in
                container.chatHistoryService.removePendingMessage(id: messageId, conversationId: conversationId)
            },
            providerTypeProvider: { [container] providerId in
                container.agentSessionConfig.providerType(forId: providerId)
            },
            selectedProviderIdProvider: { [container] in
                container.agentSessionConfig.selectedProviderId
            },
            providerInfoProvider: { [container] providerId in
                container.agentSessionConfig.allProviders.first { $0.id == providerId }
            }
        ))
    }

    private func syncPluginProjectContext() {
        pluginProjectContext.update(
            currentProjectName: windowContainer.projectVM.currentProjectName,
            currentProjectPath: windowContainer.projectVM.currentProjectPath,
            languagePreference: windowContainer.projectVM.languagePreference
        )
    }

    private func restoreSelectedConversationLanguagePreference() {
        guard let preference = windowContainer.conversationVM.getLanguagePreference() else { return }
        windowContainer.projectVM.setLanguagePreference(preference)
    }

    private func syncPluginRecentProjectsContext() {
        pluginRecentProjectsVM.setRecentProjects(
            container.recentProjectsVM.recentProjects.map {
                LumiCoreKit.Project(name: $0.name, path: $0.path, lastUsed: $0.lastUsed)
            }
        )
    }

    private func syncPluginConversationContext() {
        pluginConversationVM.windowId = windowContainer.id
        pluginConversationVM.selectedConversationId = windowContainer.conversationVM.selectedConversationId
        pluginConversationVM.updateDraftTextFromHost(windowContainer.chatDraftVM.text)
        pluginConversationVM.messagesProvider = { [container] conversationId in
            container.chatHistoryVM.loadMessagesAsync(forConversationId: conversationId) ?? []
        }
        pluginConversationVM.messagePageLoader = { [container] conversationId, limit, beforeTimestamp in
            await container.chatHistoryVM.loadMessagesPage(
                forConversationId: conversationId,
                limit: limit,
                beforeTimestamp: beforeTimestamp
            )
        }
        pluginConversationVM.messageCountProvider = { [container] conversationId in
            await container.chatHistoryVM.getMessageCount(forConversationId: conversationId)
        }
        pluginConversationVM.messageDeleteHandler = { [container] messageIds, conversationId in
            await container.chatHistoryVM.deleteMessagesAsync(
                messageIds: messageIds,
                conversationId: conversationId
            )
        }
        pluginConversationVM.statusMessageProvider = { [windowContainer] conversationId in
            windowContainer.conversationSendStatusVM.statusMessage(for: conversationId)
        }
        pluginConversationVM.verbosityPreferenceProvider = { [windowContainer] in
            windowContainer.conversationVM.getVerbosityPreference()
                .flatMap { LumiCoreKit.ResponseVerbosity(rawValue: $0.rawValue) }
        }
        pluginConversationVM.verbosityPreferenceSaver = { [windowContainer] verbosity in
            let appVerbosity = verbosity.flatMap { ResponseVerbosity(rawValue: $0.rawValue) }
            windowContainer.conversationVM.saveVerbosityPreference(appVerbosity)
        }
        pluginConversationVM.languagePreferenceProvider = { [windowContainer] in
            windowContainer.conversationVM.getLanguagePreference()
                .flatMap { LanguagePreference(rawValue: $0.rawValue) }
        }
        pluginConversationVM.languagePreferenceSaver = { [windowContainer] languagePreference in
            let appLanguagePreference = languagePreference.flatMap { LanguagePreference(rawValue: $0.rawValue) }
            windowContainer.conversationVM.saveLanguagePreference(appLanguagePreference)
            if let appLanguagePreference {
                windowContainer.projectVM.setLanguagePreference(appLanguagePreference)
            }
        }
        pluginConversationVM.pendingMessagesProvider = { [container] conversationId in
            container.chatHistoryService.pendingMessages(forConversationId: conversationId)
        }
        pluginConversationVM.pendingMessageRemover = { [container, windowContainer, pluginConversationVM] messageId in
            guard let conversationId = windowContainer.conversationVM.selectedConversationId else { return }
            _ = container.chatHistoryService.removePendingMessage(id: messageId, conversationId: conversationId)
            pluginConversationVM.notifyPendingMessagesChanged()
        }
        pluginConversationVM.pendingAttachmentsProvider = { [windowContainer] in
            windowContainer.agentAttachmentsVM.pendingAttachments
        }
        pluginConversationVM.attachmentRemover = { [windowContainer] attachmentId in
            windowContainer.agentAttachmentsVM.removeAttachment(id: attachmentId)
        }
        pluginConversationVM.imageUploadHandler = { [windowContainer] url in
            windowContainer.agentAttachmentsVM.handleImageUpload(url: url)
        }
        pluginConversationVM.screenshotDataHandler = { [windowContainer] data in
            windowContainer.agentAttachmentsVM.handleScreenshotData(data)
        }
        pluginConversationVM.draftTextAppender = { [windowContainer] text in
            windowContainer.chatDraftVM.append(text)
        }
        pluginConversationVM.draftTextSetter = { [windowContainer] text in
            windowContainer.chatDraftVM.set(text)
        }
        pluginConversationVM.textSubmitter = { [windowContainer] text in
            windowContainer.inputQueueVM.enqueueText(text)
        }
        pluginConversationVM.textEnqueuer = { [windowContainer] text in
            windowContainer.inputQueueVM.enqueueText(text)
        }
        pluginConversationVM.commandSuggestionsProvider = { [windowContainer] _ in
            windowContainer.commandSuggestionVM.suggestions.enumerated().map { index, suggestion in
                LumiCoreKit.ChatCommandSuggestion(
                    command: suggestion.command,
                    description: suggestion.description,
                    category: suggestion.category,
                    isSelected: index == windowContainer.commandSuggestionVM.selectedIndex
                )
            }
        }
        pluginConversationVM.commandSuggestionsUpdater = { [windowContainer] input in
            windowContainer.commandSuggestionVM.updateSuggestions(for: input)
        }
        pluginConversationVM.commandSuggestionsVisibilityProvider = { [windowContainer] in
            windowContainer.commandSuggestionVM.isVisible
        }
        pluginConversationVM.currentCommandSuggestionProvider = { [windowContainer] in
            guard let suggestion = windowContainer.commandSuggestionVM.getCurrentSuggestion() else { return nil }
            return LumiCoreKit.ChatCommandSuggestion(
                command: suggestion.command,
                description: suggestion.description,
                category: suggestion.category,
                isSelected: true
            )
        }
        pluginConversationVM.commandSuggestionNextSelector = { [windowContainer] in
            windowContainer.commandSuggestionVM.selectNext()
        }
        pluginConversationVM.commandSuggestionPreviousSelector = { [windowContainer] in
            windowContainer.commandSuggestionVM.selectPrevious()
        }
        pluginConversationVM.commandSuggestionsVisibilitySetter = { [windowContainer] isVisible in
            windowContainer.commandSuggestionVM.setIsVisible(isVisible)
        }
    }

    private func syncPluginConversationListContext() {
        pluginConversationListContext.selectedConversationId = windowContainer.conversationVM.selectedConversationId
        pluginConversationListContext.fetchAllConversationsProvider = { [weak windowContainer] in
            guard let windowContainer else { return [] }
            return windowContainer.conversationVM.fetchAllConversations().map(Self.conversationListItem)
        }
        pluginConversationListContext.fetchConversationsPageProvider = { [weak windowContainer] limit, offset in
            guard let windowContainer else { return [] }
            return windowContainer.conversationVM.fetchConversationsPage(limit: limit, offset: offset).map(Self.conversationListItem)
        }
        pluginConversationListContext.fetchConversationProvider = { [weak windowContainer] id in
            guard let windowContainer else { return nil }
            return windowContainer.conversationVM.fetchConversation(id: id).map(Self.conversationListItem)
        }
        pluginConversationListContext.selectConversationHandler = { [weak windowContainer] id, reason in
            windowContainer?.switchToConversation(id, reason: reason)
        }
        pluginConversationListContext.deleteConversationHandler = { [weak windowContainer] id in
            guard let windowContainer else { return false }
            guard let conversation = windowContainer.conversationVM.fetchConversation(id: id) else { return false }
            windowContainer.conversationVM.deleteConversation(conversation)
            return true
        }
        pluginConversationListContext.updateConversationTitleHandler = { [weak windowContainer] id, title in
            guard let windowContainer else { return false }
            guard let conversation = windowContainer.conversationVM.fetchConversation(id: id) else { return false }
            windowContainer.conversationVM.updateConversationTitle(conversation, newTitle: title)
            return true
        }
        pluginConversationListContext.updateProjectAssociationHandler = { [weak windowContainer] id, projectPath in
            guard let windowContainer else { return false }
            guard let conversation = windowContainer.conversationVM.fetchConversation(id: id) else { return false }
            windowContainer.conversationVM.updateProjectAssociation(for: conversation, projectPath: projectPath)
            return true
        }
        pluginConversationListContext.createConversationHandler = { [weak windowContainer] projectName, projectPath, languagePreference, chatMode in
            guard let windowContainer else { return nil }
            await windowContainer.conversationVM.createNewConversation(
                projectName: projectName,
                projectPath: projectPath,
                languagePreference: languagePreference,
                chatMode: chatMode.flatMap { ChatMode(rawValue: $0.rawValue) }
            )
            return windowContainer.conversationVM.selectedConversationId
        }
        pluginConversationListContext.switchProjectHandler = { [weak windowContainer] projectPath, reason in
            guard let windowContainer else { return }
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            windowContainer.projectVM.switchProject(
                to: Project(name: projectName, path: projectPath, lastUsed: Date()),
                reason: reason
            )
        }
        pluginConversationListContext.isConversationProcessingProvider = { [weak windowContainer] id in
            guard let windowContainer else { return false }
            return windowContainer.conversationSendStatusVM.isMessageProcessing(for: id)
        }
        pluginConversationListContext.databaseDirectoryProvider = {
            AppConfig.getDBFolderURL()
        }
        container.toolService.setConversationListContext(
            pluginConversationListContext,
            windowId: windowContainer.id,
            currentProjectName: windowContainer.projectVM.currentProjectName,
            currentProjectPath: windowContainer.projectVM.currentProjectPath
        )
    }

    private func handleFileDroppedToChat(_ url: URL) {
        let fileURL = url.standardizedFileURL
        if Self.isChatImageFileURL(fileURL) {
            windowContainer.agentAttachmentsVM.handleImageUpload(url: fileURL)
        } else {
            windowContainer.chatDraftVM.append(fileURL.path)
        }
    }

    static func isChatImageFileURL(_ url: URL) -> Bool {
        let imagePathExtensions: Set<String> = [
            "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic",
        ]
        return imagePathExtensions.contains(url.pathExtension.lowercased())
    }

    private func handleOpenFileInEditor(_ url: URL) {
        let fileURL = url.standardizedFileURL
        windowContainer.editorVM.service.open(at: fileURL)
        windowContainer.openFile(fileURL)
    }

    private func syncPluginLLMContext() {
        pluginLLMVM.selectedProviderId = container.agentSessionConfig.selectedProviderId
        pluginLLMVM.currentModel = container.agentSessionConfig.currentModel
        pluginLLMVM.isAutoMode = container.agentSessionConfig.isAutoMode
        pluginLLMVM.lastAutoRouteSummary = container.agentSessionConfig.lastAutoRouteSummary
        pluginLLMVM.updateChatModeFromHost(LumiCoreKit.ChatMode(rawValue: container.agentSessionConfig.chatMode.rawValue) ?? .build)
        pluginLLMVM.updateVerbosityFromHost(LumiCoreKit.ResponseVerbosity(rawValue: container.agentSessionConfig.verbosity.rawValue) ?? .brief)

        // 提供 provider 查询能力，让插件 VM 能获取已注册的供应商列表
        let appLLMVM = container.agentSessionConfig
        let appLLMService = appLLMVM.llmService
        pluginLLMVM.llmService = LumiCoreKit.LLMService(
            sendMessageHandler: { messages, config, tools in
                try await appLLMService.sendMessage(messages: messages, config: config, tools: tools)
            },
            providersProvider: { appLLMVM.allProviders },
            providerTypeProvider: { appLLMVM.providerType(forId: $0) },
            providerFactory: { appLLMVM.createProvider(id: $0) }
        )
        pluginLLMVM.providersProvider = { appLLMVM.allProviders }
        pluginLLMVM.providerTypeProvider = { appLLMVM.providerType(forId: $0) }
        pluginLLMVM.providerFactory = { appLLMVM.createProvider(id: $0) }

        pluginLLMVM.chatModeSetter = { [container, windowContainer] chatMode in
            guard let appChatMode = ChatMode(rawValue: chatMode.rawValue) else { return }
            container.agentSessionConfig.setChatMode(appChatMode)
            windowContainer.conversationVM.saveChatModePreference(appChatMode)
        }
        pluginLLMVM.verbositySetter = { [container, windowContainer] verbosity in
            guard let appVerbosity = ResponseVerbosity(rawValue: verbosity.rawValue) else { return }
            container.agentSessionConfig.setVerbosity(appVerbosity)
            windowContainer.conversationVM.saveVerbosityPreference(appVerbosity)
        }
    }

    private func syncLayoutContext() {
        pluginLayoutContext.update(
            bottomPanelVisible: windowContainer.layoutVM.bottomPanelVisible,
            contentPanelVisible: windowContainer.layoutVM.contentPanelVisible,
            editorVisible: windowContainer.layoutVM.editorVisible,
            railVisible: windowContainer.layoutVM.railVisible,
            rightSidebarVisible: windowContainer.layoutVM.rightSidebarVisible,
            activeViewContainerIcon: windowContainer.layoutVM.activeViewContainerIcon,
            selectedAgentSidebarTabId: windowContainer.layoutVM.selectedAgentSidebarTabId,
            selectedAgentDetailId: windowContainer.layoutVM.selectedAgentDetailId,
            layoutRatios: windowContainer.layoutVM.layoutRatios
        )
    }

    private func applyLayoutContextToWindow() {
        let layoutVM = windowContainer.layoutVM
        layoutVM.restorePersisted(activeViewContainerIcon: pluginLayoutContext.activeViewContainerIcon)
        layoutVM.restorePersisted(tabId: pluginLayoutContext.selectedAgentSidebarTabId)
        layoutVM.restorePersisted(detailId: pluginLayoutContext.selectedAgentDetailId)
        layoutVM.restorePersisted(ratios: pluginLayoutContext.layoutRatios)
        layoutVM.restorePersisted(bottomPanelVisible: pluginLayoutContext.bottomPanelVisible)
        layoutVM.restorePersisted(contentPanelVisible: pluginLayoutContext.contentPanelVisible)
        layoutVM.restorePersisted(editorVisible: pluginLayoutContext.editorVisible)
        layoutVM.restorePersisted(railVisible: pluginLayoutContext.railVisible)
        layoutVM.restorePersisted(rightSidebarVisible: pluginLayoutContext.rightSidebarVisible)
    }

    private func configureProjectContextActions() {
        PluginProjectContext.switchProjectHandler = { [container, windowContainer] project, reason in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            targetWindow.projectVM.switchProject(
                to: Project(name: project.name, path: project.path, lastUsed: project.lastUsed),
                reason: reason
            )
        }
    }

    private func configureProjectConversationContext() {
        pluginConversationVM.switchToLatestConversationHandler = { [windowContainer] projectPath in
            windowContainer.conversationVM.switchToLatestConversation(forProject: projectPath)
        }
        pluginConversationVM.createNewConversationHandler = { [windowContainer] projectName, projectPath, languagePreference, chatMode in
            await windowContainer.conversationVM.createNewConversation(
                projectName: projectName,
                projectPath: projectPath,
                languagePreference: languagePreference,
                chatMode: chatMode.flatMap { ChatMode(rawValue: $0.rawValue) }
            )
        }
        pluginConversationVM.databaseDirectoryProvider = {
            AppConfig.getDBFolderURL()
        }
    }

    private func configureEditorContextActions() {
        // 提供主题能力
        pluginEditorContext.configureThemeProvider { [container] in
            container.themeVM.activeChromeTheme
        }
        pluginEditorContext.configureFileIconThemeProvider { [container] in
            container.themeVM.activeFileIconTheme
        }
        // 提供编辑器操作能力
        pluginEditorContext.openFileHandler = { [container, windowContainer] url in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            targetWindow.editorVM.service.open(at: url)
        }
        pluginEditorContext.refreshProjectContextHandler = { [container, windowContainer] projectPath in
            let targetWindow = Self.targetWindowContainer(fallback: windowContainer, rootContainer: container)
            await targetWindow.editorVM.service.refreshProjectContext(for: projectPath)
        }
        pluginEditorContext.addToConversationHandler = { fileURL, windowId in
            NotificationCenter.postFileDroppedToChat(fileURL: fileURL, windowId: windowId)
        }
        EditorContext.syncSelectedFileNotificationName = .syncSelectedFile
        // 同步当前选中文件
        syncEditorContextFileURL()
    }

    private func syncEditorContextFileURL() {
        pluginEditorContext.updateCurrentFileURL(windowContainer.editorVM.service.currentFileURL)
    }

    private func configureConversationListContext() {
        syncPluginConversationListContext()
    }

    private static func conversationListItem(_ conversation: Conversation) -> LumiCoreKit.ConversationListItem {
        LumiCoreKit.ConversationListItem(
            id: conversation.id,
            projectPath: conversation.projectId,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt
        )
    }

    private static func conversationListChange(from notification: Notification) -> LumiCoreKit.ConversationListChange? {
        guard
            let userInfo = notification.userInfo,
            let typeRaw = userInfo[ConversationChangeUserInfoKey.type] as? String,
            let idRaw = userInfo[ConversationChangeUserInfoKey.conversationId] as? String,
            let type = LumiCoreKit.ConversationListChangeType(rawValue: typeRaw),
            let conversationId = UUID(uuidString: idRaw)
        else {
            return nil
        }

        return LumiCoreKit.ConversationListChange(type: type, conversationId: conversationId)
    }

    private static func targetWindowContainer(
        for context: PluginContext,
        fallback: WindowContainer,
        rootContainer: RootContainer
    ) -> WindowContainer {
        if let windowId = context.windowId,
           let targetWindow = rootContainer.windowManagerVM.getContainer(windowId) {
            return targetWindow
        }
        return targetWindowContainer(fallback: fallback, rootContainer: rootContainer)
    }

    private static func targetWindowContainer(
        fallback: WindowContainer,
        rootContainer: RootContainer
    ) -> WindowContainer {
        rootContainer.windowManagerVM.activeWindowContainer ?? fallback
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Parameter container: 窗口容器
    /// - Returns: 包装在 RootView 中的视图
    func inRootView(container: WindowContainer) -> some View {
        RootView(container: container, content: { self })
    }

    /// Preview 专用：使用 fallback WindowContainer 注入环境对象
    ///
    /// 生产代码请使用 `inRootView(container:)` 传入窗口容器。
    /// 此方法仅用于 #Preview 和设置窗口等无窗口上下文的场景。
    func inRootView() -> some View {
        inRootView(container: WindowContainer(container: RootContainer.shared))
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView(container: WindowContainer(container: RootContainer.shared))
        .withDebugBar()
}
