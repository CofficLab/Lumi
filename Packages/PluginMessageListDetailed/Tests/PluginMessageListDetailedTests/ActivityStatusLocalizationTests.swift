import Foundation
import ProviderConversationState
import ProviderMessage
import Testing
@testable import PluginMessageListDetailed

/// 活动状态行的本地化契约（#886）。
///
/// 活动状态行此前用 `String(localized:defaultValue:)` 查 main bundle，
/// 且 catalog 里的 `en` 值本身就是中文；具体工具描述还直接拼了
/// 「正在\(description)…」。英文界面因此整行显示中文。
///
/// 这里分两层锁住：
/// 1. 注入式解析器证明文案**一定经过本地化**，不是硬编码字面量；
/// 2. 编译产物里的 `.lproj/Localizable.strings` 证明各语言确实有译文。
struct ActivityStatusLocalizationTests {
    private static let languages = ["en", "zh-Hans", "zh-Hant", "zh-HK", "zh-TW"]

    /// 活动状态行的全部文案键。
    private static let keys = [
        "Sending message…",
        "Thinking…",
        "Executing tool…",
        "Running %@…",
        "Waiting for your input…",
    ]

    private static func marker(_ value: String) -> String { "[\(value)]" }

    // MARK: - 测试夹具

    @MainActor
    static func services(
        conversationState: StubConversationStateCapability?,
        selected: UUID? = UUID(),
        resolveText: @escaping (String) -> String = { $0 }
    ) -> MessageListServices {
        MessageListServices(
            conversations: StubConversationCapability(selectedConversationID: selected),
            conversationState: conversationState,
            developerModeState: DeveloperModeStateViewModel(),
            messages: nil, rendering: nil, streaming: nil, toolManager: nil,
            agentTurn: nil, promptSuggestions: nil, promptSuggestionExecutor: nil,
            project: nil, toolbar: nil, chat: nil
        )
        .withResolver(resolveText)
    }

    @MainActor
    static func snapshot(
        conversationID: UUID,
        activity: ConversationActivity?,
        job: ConversationJobActivity = ConversationJobActivity()
    ) -> StubConversationStateCapability {
        StubConversationStateCapability(
            snapshot: ConversationStateSnapshot(
                conversationID: conversationID,
                activity: activity,
                jobActivity: job
            )
        )
    }

    // MARK: - 注入解析器

    @MainActor
    @Test("活动状态文案全部经过注入的本地化解析（#886）")
    func activityContentUsesInjectedLocalization() {
        let conversationID = UUID()
        var requestedKeys: [String] = []
        let resolve: (String) -> String = { key in
            requestedKeys.append(key)
            return Self.marker(key)
        }

        let sending = Self.services(
            conversationState: Self.snapshot(conversationID: conversationID, activity: .sending),
            selected: conversationID,
            resolveText: resolve
        )
        #expect(
            sending.activityMessage(for: conversationID)?.content
                == "[Sending message…]"
        )

        let thinking = Self.services(
            conversationState: Self.snapshot(conversationID: conversationID, activity: .thinking),
            selected: conversationID,
            resolveText: resolve
        )
        #expect(
            thinking.activityMessage(for: conversationID)?.content
                == "[Thinking…]"
        )

        let executing = Self.services(
            conversationState: Self.snapshot(
                conversationID: conversationID,
                activity: .executingTool,
                job: ConversationJobActivity(
                    currentJobCount: 1,
                    runningJobCount: 1,
                    recentJobDescription: "Sources/App.swift"
                )
            ),
            selected: conversationID,
            resolveText: resolve
        )
        // 具体工具描述走可本地化的格式化模板，占位符在解析之后替换。
        #expect(
            executing.activityMessage(for: conversationID)?.content
                == "[Running Sources/App.swift…]"
        )

        // 工具执行但没有可拼接的描述时走通用文案分支。
        let executingGeneric = Self.services(
            conversationState: Self.snapshot(
                conversationID: conversationID,
                activity: .executingTool,
                job: ConversationJobActivity(currentJobCount: 1, runningJobCount: 1)
            ),
            selected: conversationID,
            resolveText: resolve
        )
        #expect(
            executingGeneric.activityMessage(for: conversationID)?.content
                == "[Executing tool…]"
        )

        let waiting = Self.services(
            conversationState: Self.snapshot(conversationID: conversationID, activity: .waitingForUser),
            selected: conversationID,
            resolveText: resolve
        )
        #expect(
            waiting.activityMessage(for: conversationID)?.content
                == "[Waiting for your input…]"
        )

        #expect(
            Set(requestedKeys) == Set(Self.keys),
            "活动文案没有全部经过本地化解析，实际解析了 \(requestedKeys)"
        )
    }

    @MainActor
    @Test("活动状态文案不含中文字面量（#886）")
    func activityContentHasNoChineseLiteral() {
        let conversationID = UUID()
        let activities: [ConversationActivity] = [.sending, .thinking, .executingTool, .waitingForUser]

        for activity in activities {
            let row = Self.services(
                conversationState: Self.snapshot(
                    conversationID: conversationID,
                    activity: activity,
                    job: ConversationJobActivity(
                        currentJobCount: 1,
                        runningJobCount: 1,
                        recentJobDescription: "Sources/App.swift"
                    )
                ),
                selected: conversationID
            ).activityMessage(for: conversationID)

            let content = try? #require(row?.content)
            #expect(
                content?.contains(where: { $0.unicodeScalars.contains(where: { $0.value > 0x2E80 }) }) == false,
                "\(activity) 的活动文案仍含中文字面量"
            )
        }
    }

    // MARK: - 编译产物译文

    @Test("活动状态词条在所有规范语言下都有译文（#886）")
    func activityLabelsHaveTranslationsInCompiledBundle() throws {
        for language in Self.languages {
            let table = try Self.compiledStrings(language: language)
            for (key, translations) in Self.expected {
                #expect(
                    table[key] == translations[language],
                    "\(language) 下 \(key) 译文缺失或不符，详细消息列表会回退到其它语言"
                )
            }
        }
    }

    @Test("旧的 status.* 词条已从 catalog 移除（#886）")
    func legacyStatusKeysAreRemoved() throws {
        for language in Self.languages {
            let table = try Self.compiledStrings(language: language)
            for key in ["status.sending", "status.thinking", "status.executing-tool", "status.waiting-for-user"] {
                #expect(
                    table[key] == nil,
                    "\(language) 下仍残留旧词条 \(key)"
                )
            }
        }
    }

    // MARK: - Helpers

    /// 活动状态词条在 5 种规范语言下的预期译文。
    static let expected: [String: [String: String]] = [
        "Sending message…": [
            "en": "Sending message…", "zh-Hans": "正在发送消息…",
            "zh-Hant": "正在傳送訊息…", "zh-HK": "正在傳送訊息…", "zh-TW": "正在傳送訊息…",
        ],
        "Thinking…": [
            "en": "Thinking…", "zh-Hans": "正在思考…",
            "zh-Hant": "正在思考…", "zh-HK": "正在思考…", "zh-TW": "正在思考…",
        ],
        "Executing tool…": [
            "en": "Executing tool…", "zh-Hans": "正在执行工具…",
            "zh-Hant": "正在執行工具…", "zh-HK": "正在執行工具…", "zh-TW": "正在執行工具…",
        ],
        "Running %@…": [
            "en": "Running %@…", "zh-Hans": "正在%@…",
            "zh-Hant": "正在%@…", "zh-HK": "正在%@…", "zh-TW": "正在%@…",
        ],
        "Waiting for your input…": [
            "en": "Waiting for your input…", "zh-Hans": "等待你的输入…",
            "zh-Hant": "等待你的輸入…", "zh-HK": "等待你的輸入…", "zh-TW": "等待你的輸入…",
        ],
    ]

    static func compiledStrings(language: String) throws -> [String: String] {
        let bundle = pluginLocalization.bundle
        let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
    }
}
