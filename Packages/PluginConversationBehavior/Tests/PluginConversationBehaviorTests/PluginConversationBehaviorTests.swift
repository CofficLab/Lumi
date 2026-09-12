import Foundation
import Testing
import KernelCore
import KitLLM
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import ProviderToast

@testable import PluginConversationBehavior

@Suite("PluginConversationBehavior")
@MainActor
struct PluginConversationBehaviorTests {
    private func makeKernel() throws -> (KernelCoreContainer, DefaultConversationManager, DefaultChatSectionProviding) {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        return (kernel, conversations, chat)
    }

    private func makeConversation(in conversations: DefaultConversationManager) throws -> UUID {
        try conversations.createConversation(
            title: "Test",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
    }

    @Test("Reasoning 插件注册 ActionBar 按钮")
    func reasoningRegisters() throws {
        let (kernel, _, _) = try makeKernel()
        let plugin = ConversationReasoningPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ConversationManaging).self) != nil)
    }

    @Test("Reasoning 档位经 ConversationManaging 读写")
    func reasoningRoundTrip() {
        let conversations = DefaultConversationManager()
        conversations.setGlobalReasoningEffort(.high)
        #expect(conversations.reasoningEffortOptional(for: nil) == .high)
        conversations.clearReasoningEffort(for: nil)
        #expect(conversations.reasoningEffortOptional(for: nil) == nil)
    }

    @Test("Language hook prepends localized transient system instruction")
    func languageHookInjectsPreferenceAndPreservesHistory() throws {
        let conversations = DefaultConversationManager()
        let conversationID = try makeConversation(in: conversations)
        conversations.setLanguage(.english, for: conversationID)
        let original = LLMMessage(role: .user, content: "Hello")
        let context = WillSendToLLMContext(messages: [original], conversationID: conversationID)

        let result = ConversationLanguageHook(conversations: conversations).apply(to: context)

        #expect(result.messages.count == 2)
        #expect(result.messages.first == LLMMessage(role: .system, content: "## Language Preference\nPlease respond in English."))
        #expect(result.messages.last == original)
        #expect(context.messages == [original])
    }

    @Test("Language hook leaves context unchanged after manager deallocation")
    func languageHookWithoutManagerIsNoop() {
        let original = LLMMessage(role: .user, content: "Hello")
        let context = WillSendToLLMContext(messages: [original], conversationID: UUID())
        var conversations: DefaultConversationManager? = DefaultConversationManager()
        let hook = ConversationLanguageHook(conversations: conversations)
        conversations = nil

        #expect(hook.apply(to: context).messages == [original])
    }

    @Test("Language plugin registers and cancels its toolbar and lifecycle hook")
    func languagePluginLifecycle() async throws {
        let (kernel, _, chat) = try makeKernel()
        let hooks = DefaultLifecycleHooksProvider()
        try kernel.registerProvider((any LifecycleHooksProviding).self, hooks)
        let plugin = ConversationLanguagePlugin()

        try plugin.onBoot(kernel: kernel)
        #expect(chat.barItems.map(\.id) == ["com.coffic.lumi.plugin.conversation-language.toolbar-button"])
        #expect(hooks.revision == 1)

        let original = LLMMessage(role: .user, content: "Hello")
        let context = WillSendToLLMContext(messages: [original], conversationID: UUID())
        let injected = await hooks.runWillSendToLLM(context)
        #expect(injected.messages.count == 2)
        #expect(injected.messages.first?.role == .system)

        try plugin.onShutdown(kernel: kernel)
        #expect(chat.barItems.isEmpty)
        #expect(hooks.revision == 2)
        #expect(await hooks.runWillSendToLLM(context).messages == [original])
    }

    @Test("Language selection updates conversation and global preference")
    func languageSelectionUpdatesPreferencesAndToast() throws {
        let conversations = DefaultConversationManager()
        let conversationID = try makeConversation(in: conversations)
        let toast = RecordingToastProvider()
        let view = LanguageToolbarView(conversations: conversations, toast: toast)

        view.select(.english)

        #expect(conversations.language(for: conversationID) == .english)
        #expect(conversations.globalLanguage == .english)
        #expect(toast.shownToasts.last?.detail == "EN")
    }

    @Test("Language selection without a selected conversation updates global preference")
    func languageSelectionWithoutConversationUpdatesGlobalPreference() {
        let conversations = DefaultConversationManager()
        let toast = RecordingToastProvider()
        let view = LanguageToolbarView(conversations: conversations, toast: toast)

        view.select(.english)

        #expect(conversations.selectedConversationID == nil)
        #expect(conversations.globalLanguage == .english)
        #expect(toast.shownToasts.count == 1)
    }

    @Test("Reasoning selection updates conversation and global preference")
    func reasoningSelectionUpdatesPreferencesAndToast() throws {
        let conversations = DefaultConversationManager()
        let conversationID = try makeConversation(in: conversations)
        let toast = RecordingToastProvider()
        let view = ReasoningActionBarButton(conversations: conversations, toast: toast)

        view.apply(.effort(.low))

        #expect(conversations.reasoningEffortOptional(for: conversationID) == .low)
        #expect(conversations.globalReasoningEffort == .low)
        #expect(toast.shownToasts.last?.detail == "LOW")

        view.apply(.off)
        #expect(conversations.reasoningEffortOptional(for: conversationID) == nil)
        #expect(conversations.globalReasoningEffort == nil)
        #expect(toast.shownToasts.count == 2)
    }
}

@MainActor
private final class RecordingToastProvider: ToastProviding {
    private(set) var shownToasts: [LumiToast] = []

    func show(_ toast: LumiToast) {
        shownToasts.append(toast)
    }
}
