import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderConversation

@testable import PluginConversationMode

@Suite("ConversationModePlugin")
@MainActor
struct ConversationModePluginTests {
    @Test("插件 onBoot/onShutdown 不抛错且 Provider 保持可用")
    func pluginLifecycle() throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)

        let plugin = ConversationModePlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ConversationManaging).self) != nil)
        #expect(kernel.resolveProvider((any ChatSectionProviding).self) != nil)

        try plugin.onShutdown(kernel: kernel)
        #expect(kernel.resolveProvider((any ChatSectionProviding).self) != nil)
    }

    @Test("全局自动化级别通过 ConversationManaging 读写")
    func automationLevelRoundTrip() {
        let conversations = DefaultConversationManager()
        conversations.setGlobalAutomationLevel(.autonomous)
        #expect(conversations.globalAutomationLevel == .autonomous)
        #expect(conversations.automationLevel(for: nil) == .autonomous)
    }

    @Test("会话观察盒通过类型化事件刷新并支持取消")
    func conversationObservationBoxUsesTypedEvents() {
        let conversations = DefaultConversationManager()
        let observation = ConversationManagerObservationBox(conversations: conversations)
        var eventCount = 0
        let handle = observation.addObserver { _ in eventCount += 1 }

        conversations.setGlobalAutomationLevel(.autonomous)
        #expect(eventCount == 1)

        handle.cancel()
        conversations.setGlobalAutomationLevel(.chat)
        #expect(eventCount == 1)

        observation.cancel()
    }

    /// 回归 #919：弹层选项名称与说明、chip tooltip 必须经过插件本地化解析，
    /// 而不是读取 `AutomationLevel` 里写死的中文字面量。
    ///
    /// 用注入的替身解析器断言「文案确实来自解析器」，因为真实解析结果取决于
    /// 宿主首选语言，无法在 CI 上给出与语言无关的期望值。
    @Test("自动化等级名称与说明经过注入的本地化解析（回归 #919）")
    func automationLevelTextUsesInjectedLocalization() {
        let cases: [(AutomationLevel, String, String)] = [
            (.chat, "Chat", "Chat Description"),
            (.build, "Build", "Build Description"),
            (.autonomous, "Autonomous", "Autonomous Description"),
        ]
        let resolve: (String) -> String = { "localized:\($0)" }

        for (level, nameKey, descriptionKey) in cases {
            #expect(
                level.localizedDisplayName(resolve: resolve) == "localized:\(nameKey)",
                "自动化等级名称未经过本地化解析：\(level.rawValue)"
            )
            #expect(
                level.localizedDescription(resolve: resolve) == "localized:\(descriptionKey)",
                "自动化等级说明未经过本地化解析：\(level.rawValue)"
            )
        }
    }

    /// 回归 #919：名称与说明词条必须在编译产物里对每种受支持语言都有译文，
    /// 否则英文界面会显示中文，或中文界面回落成英文 key。
    @Test("自动化等级词条在所有规范语言下都有译文（回归 #919）")
    func automationLevelStringsHaveTranslationsInCompiledBundle() throws {
        let expected: [String: [String: String]] = [
            "Chat": [
                "en": "Chat", "zh-Hans": "对话", "zh-Hant": "對話",
                "zh-HK": "對話", "zh-TW": "對話",
            ],
            "Build": [
                "en": "Build", "zh-Hans": "构建", "zh-Hant": "構建",
                "zh-HK": "構建", "zh-TW": "構建",
            ],
            "Autonomous": [
                "en": "Autonomous", "zh-Hans": "自主", "zh-Hant": "自主",
                "zh-HK": "自主", "zh-TW": "自主",
            ],
            "Chat Description": [
                "en": "Conversation only; does not run any tools",
                "zh-Hans": "只进行对话，不执行任何工具",
                "zh-Hant": "只進行對話，不執行任何工具",
                "zh-HK": "只進行對話，不執行任何工具",
                "zh-TW": "只進行對話，不執行任何工具",
            ],
            "Build Description": [
                "en": "Runs tools; high-risk actions require confirmation",
                "zh-Hans": "可以执行工具，高风险需要确认",
                "zh-Hant": "可以執行工具，高風險需要確認",
                "zh-HK": "可以執行工具，高風險需要確認",
                "zh-TW": "可以執行工具，高風險需要確認",
            ],
            "Autonomous Description": [
                "en": "Runs tools autonomously and keeps working toward the task",
                "zh-Hans": "可以自主执行工具，持续推进任务",
                "zh-Hant": "可以自主執行工具，持續推進任務",
                "zh-HK": "可以自主執行工具，持續推進任務",
                "zh-TW": "可以自主執行工具，持續推進任務",
            ],
        ]

        for (key, translations) in expected {
            for (language, translation) in translations {
                let table = try Self.compiledStrings(language: language)
                #expect(
                    table[key] == translation,
                    "\(language) 下 \(key) 译文缺失或不符，自动化等级控件会回退到其它语言"
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
}
