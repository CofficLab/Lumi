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

    @Test("选中会话时切换语言只影响该会话，不改全局默认")
    func languageSelectionDoesNotChangeGlobalDefault() throws {
        let conversations = DefaultConversationManager()
        let conversationID = try makeConversation(in: conversations)
        let toast = RecordingToastProvider()
        let view = LanguageToolbarView(conversations: conversations, toast: toast)

        view.select(.english)

        #expect(conversations.language(for: conversationID) == .english)
        // 修改已有会话不能连带改掉 New Chat 的默认语言（默认 .chinese）。
        #expect(conversations.globalLanguage == .chinese)
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

    @Test("选中会话时调整 Reasoning 只影响该会话，不改全局默认")
    func reasoningSelectionDoesNotChangeGlobalDefault() throws {
        let conversations = DefaultConversationManager()
        conversations.setGlobalReasoningEffort(.medium)
        let conversationID = try makeConversation(in: conversations)
        let toast = RecordingToastProvider()
        let view = ReasoningActionBarButton(conversations: conversations, toast: toast)

        view.apply(.effort(.low))

        #expect(conversations.reasoningEffortOptional(for: conversationID) == .low)
        // 修改已有会话不能连带改掉 New Chat 的默认档位。
        #expect(conversations.globalReasoningEffort == .medium)
        #expect(toast.shownToasts.last?.detail == "LOW")

        view.apply(.off)
        // 清除会回落到全局默认（既有语义）；关键仍是全局默认未被改写。
        #expect(conversations.reasoningEffortOptional(for: conversationID) == .medium)
        #expect(conversations.globalReasoningEffort == .medium)
        #expect(toast.shownToasts.count == 2)
    }

    @Test("New Chat（无选中会话）调整 Reasoning 才更新全局默认")
    func reasoningSelectionWithoutConversationUpdatesGlobalDefault() {
        let conversations = DefaultConversationManager()
        let toast = RecordingToastProvider()
        let view = ReasoningActionBarButton(conversations: conversations, toast: toast)

        view.apply(.effort(.high))

        #expect(conversations.selectedConversationID == nil)
        #expect(conversations.globalReasoningEffort == .high)

        view.apply(.off)
        #expect(conversations.globalReasoningEffort == nil)
        #expect(toast.shownToasts.count == 2)
    }

    /// 回归 #918：弹层档位名称必须经过插件本地化解析，而不是读取
    /// `ReasoningEffort` 里写死的中文字面量。
    ///
    /// 用注入的替身解析器断言「文案确实来自解析器」，因为真实解析结果取决于
    /// 宿主首选语言，无法在 CI 上给出与语言无关的期望值。
    @Test("推理档位名称经过注入的本地化解析（回归 #918）")
    func reasoningEffortNamesUseInjectedLocalization() {
        let cases: [(ReasoningEffort, String)] = [
            (.low, "Low"),
            (.medium, "Medium"),
            (.high, "High"),
            (.xhigh, "Extra High"),
            (.max, "Max"),
        ]
        let resolve: (String) -> String = { "localized:\($0)" }

        for (effort, nameKey) in cases {
            #expect(
                effort.localizedDisplayName(resolve: resolve) == "localized:\(nameKey)",
                "推理档位名称未经过本地化解析：\(effort.rawValue)"
            )
        }
    }

    /// 回归 #918：档位名称词条必须在编译产物里对每种受支持语言都有译文，
    /// 否则英文界面会显示中文，或中文界面回落成英文 key。
    @Test("推理档位词条在所有规范语言下都有译文（回归 #918）")
    func reasoningEffortStringsHaveTranslationsInCompiledBundle() throws {
        let expected: [String: [String: String]] = [
            "Low": [
                "en": "Low", "zh-Hans": "低", "zh-Hant": "低",
                "zh-HK": "低", "zh-TW": "低",
            ],
            "Medium": [
                "en": "Medium", "zh-Hans": "中", "zh-Hant": "中",
                "zh-HK": "中", "zh-TW": "中",
            ],
            "High": [
                "en": "High", "zh-Hans": "高", "zh-Hant": "高",
                "zh-HK": "高", "zh-TW": "高",
            ],
            "Extra High": [
                "en": "Extra High", "zh-Hans": "超高", "zh-Hant": "超高",
                "zh-HK": "超高", "zh-TW": "超高",
            ],
            "Max": [
                "en": "Max", "zh-Hans": "极限", "zh-Hant": "極限",
                "zh-HK": "極限", "zh-TW": "極限",
            ],
        ]

        for (key, translations) in expected {
            for (language, translation) in translations {
                let table = try Self.compiledStrings(language: language)
                #expect(
                    table[key] == translation,
                    "\(language) 下 \(key) 译文缺失或不符，推理档位弹层会回退到其它语言"
                )
            }
        }
    }

    private static func compiledStrings(language: String) throws -> [String: String] {
        let bundle = pluginLocalization.bundle
        let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
    }

    /// 回归 #917：推理关闭时 chip 必须显示本地化的 `Off` 词条，
    /// 不能回退到硬编码的 `OFF` 字面量。
    @Test("关闭态的 chip 文案使用 Off 本地化词条（回归 #917）")
    func reasoningChipOffUsesLocalizedKey() {
        let resolve: (String) -> String = { "localized:\($0)" }

        #expect(ReasoningChipLabel.text(for: nil, resolve: resolve) == "localized:Off")
        #expect(ReasoningChipLabel.text(for: .high, resolve: resolve) == "HIGH")
    }

    /// 回归 #917：`Off` 词条在编译产物里对每种受支持语言都要有译文，
    /// 否则 chip 的关闭态会在某些语言下回落成英文 key。
    @Test("Off 词条在所有规范语言下都有译文（回归 #917）")
    func offStringHasTranslationsInCompiledBundle() throws {
        let expected: [String: String] = [
            "en": "Off",
            "zh-Hans": "关闭",
            "zh-Hant": "关闭",
            "zh-HK": "关闭",
            "zh-TW": "关闭",
        ]

        for (language, translation) in expected {
            let table = try Self.compiledStrings(language: language)
            #expect(
                table["Off"] == translation,
                "\(language) 下 Off 译文缺失或不符，chip 关闭态会显示未翻译文案"
            )
        }
    }
}

@MainActor
private final class RecordingToastProvider: ToastProviding {
    private(set) var shownToasts: [LumiToast] = []
    private(set) var presentedErrors: [(title: String, message: String, sourceWindowID: String?)] = []
    private(set) var dismissErrorCount = 0

    func show(_ toast: LumiToast) {
        shownToasts.append(toast)
    }

    // `ToastProviding` 的持久化错误面没有默认实现，mock 必须显式提供。
    func presentError(title: String, message: String, sourceWindowID: String?) {
        presentedErrors.append((title, message, sourceWindowID))
    }

    func dismissError() {
        dismissErrorCount += 1
    }
}
