import Foundation
import ProviderAgentLoop
import ProviderConversationState
import ProviderMessage
import ProviderMessageStreaming
import Testing
@testable import PluginMessageListBrief

/// Brief 活动状态与过程摘要的文案投影（#893）。
///
/// 两条链路此前直接拼接中文字面量：`AgentActivityProjection.resolve` 产出
/// 底部活动行，`AgentTurnVM.processDisclosureTitle` 产出过程折叠标题与耗时。
/// 用注入式解析器锁住「文案一定经过本地化」，再用编译产物测试锁住各语言译文。
struct ActivityLocalizationTests {
    private let conversationID = UUID()
    private static let languages = ["en", "zh-Hans", "zh-Hant", "zh-HK", "zh-TW"]

    private static func marker(_ value: String) -> String { "[\(value)]" }

    // MARK: - 注入解析器

    @Test("活动标题经过注入的本地化解析（#893）")
    func activityTitlesUseInjectedLocalization() {
        let resolve = Self.marker

        let sending = AgentActivityProjection.resolve(
            conversationState: nil,
            streamingStage: .sending,
            resolve: resolve
        )
        #expect(sending?.title == "[Sending message…]")

        let thinking = AgentActivityProjection.resolve(
            conversationState: nil,
            streamingStage: .thinking,
            resolve: resolve
        )
        #expect(thinking?.title == "[Thinking…]")

        let generating = AgentActivityProjection.resolve(
            conversationState: nil,
            streamingStage: .generating,
            resolve: resolve
        )
        #expect(generating?.title == "[Generating reply…]")

        let running = AgentActivityProjection.resolve(
            conversationState: ConversationStateSnapshot(
                conversationID: conversationID,
                agentLoopState: .running
            ),
            streamingStage: .idle,
            resolve: resolve
        )
        #expect(running?.title == "[Processing…]")
    }

    @Test("工具与等待阶段的活动文案经过注入的本地化解析（#893）")
    func toolActivityUsesInjectedLocalization() {
        let resolve = Self.marker

        let single = AgentActivityProjection.resolve(
            conversationState: ConversationStateSnapshot(
                conversationID: conversationID,
                activity: .executingTool,
                jobActivity: ConversationJobActivity(
                    currentJobCount: 1,
                    runningJobCount: 1,
                    recentJobDescription: "Sources/App.swift"
                )
            ),
            streamingStage: .idle,
            resolve: resolve
        )
        #expect(single?.title == "[Executing]")
        // 单任务沿用工具描述原文，不加「最近：」前缀。
        #expect(single?.detail == "Sources/App.swift")

        let multiple = AgentActivityProjection.resolve(
            conversationState: ConversationStateSnapshot(
                conversationID: conversationID,
                activity: .executingTool,
                jobActivity: ConversationJobActivity(
                    currentJobCount: 3,
                    runningJobCount: 2,
                    recentJobDescription: "Sources/App.swift"
                )
            ),
            streamingStage: .idle,
            resolve: resolve
        )
        #expect(multiple?.title == "[Executing 2 tasks]")
        #expect(multiple?.detail == "[Latest: Sources/App.swift]")

        let waiting = AgentActivityProjection.resolve(
            conversationState: ConversationStateSnapshot(
                conversationID: conversationID,
                activity: .waitingForUser
            ),
            streamingStage: .idle,
            resolve: resolve
        )
        #expect(waiting?.title == "[Waiting for your confirmation]")
    }

    @Test("过程折叠标题与耗时经过注入的本地化解析（#893）")
    func disclosureTitleUsesInjectedLocalization() {
        let resolve = Self.marker
        let started = Date()

        let running = Self.disclosureTitle(
            startedAt: started,
            endedAt: nil,
            state: .running,
            acceptsLiveActivity: true,
            now: started.addingTimeInterval(12),
            resolve: resolve
        )
        #expect(running == "[Running] · [1 steps] · [12s]")

        let completed = Self.disclosureTitle(
            startedAt: started,
            endedAt: started.addingTimeInterval(12),
            state: .completed,
            acceptsLiveActivity: false,
            now: started.addingTimeInterval(30),
            resolve: resolve
        )
        #expect(completed == "[Completed after 1 steps] · [12s]")
    }

    @Test("耗时单位依次切换为秒/分/时（#893）")
    func durationUnitsUseInjectedLocalization() {
        let resolve = Self.marker
        let started = Date()

        func title(seconds: TimeInterval) -> String {
            Self.disclosureTitle(
                startedAt: started,
                endedAt: nil,
                state: .running,
                acceptsLiveActivity: true,
                now: started.addingTimeInterval(seconds),
                resolve: resolve
            )
        }

        #expect(title(seconds: 45).hasSuffix("[45s]"))
        #expect(title(seconds: 90).hasSuffix("[1m]"))
        #expect(title(seconds: 3600).hasSuffix("[1h]"))
        #expect(title(seconds: 3900).hasSuffix("[1h 5m]"))
    }

    // MARK: - 编译产物译文

    @Test("活动与过程摘要词条在所有规范语言下都有译文（#893）")
    func activityLabelsHaveTranslationsInCompiledBundle() throws {
        let expected: [String: [String: String]] = [
            "Sending message…": [
                "en": "Sending message…", "zh-Hans": "正在发送消息…",
                "zh-Hant": "正在傳送訊息…", "zh-HK": "正在傳送訊息…", "zh-TW": "正在傳送訊息…",
            ],
            "Thinking…": [
                "en": "Thinking…", "zh-Hans": "正在思考…",
                "zh-Hant": "正在思考…", "zh-HK": "正在思考…", "zh-TW": "正在思考…",
            ],
            "Generating reply…": [
                "en": "Generating reply…", "zh-Hans": "正在生成回复…",
                "zh-Hant": "正在產生回覆…", "zh-HK": "正在產生回覆…", "zh-TW": "正在產生回覆…",
            ],
            "Executing": [
                "en": "Executing", "zh-Hans": "正在执行",
                "zh-Hant": "正在執行", "zh-HK": "正在執行", "zh-TW": "正在執行",
            ],
            "Executing %lld tasks": [
                "en": "Executing %lld tasks", "zh-Hans": "正在执行 %lld 个任务",
                "zh-Hant": "正在執行 %lld 個任務", "zh-HK": "正在執行 %lld 個任務",
                "zh-TW": "正在執行 %lld 個任務",
            ],
            "Latest: %@": [
                "en": "Latest: %@", "zh-Hans": "最近：%@",
                "zh-Hant": "最近：%@", "zh-HK": "最近：%@", "zh-TW": "最近：%@",
            ],
            "Waiting for your confirmation": [
                "en": "Waiting for your confirmation", "zh-Hans": "等待你的确认",
                "zh-Hant": "等待你的確認", "zh-HK": "等待你的確認", "zh-TW": "等待你的確認",
            ],
            "Processing…": [
                "en": "Processing…", "zh-Hans": "正在处理…",
                "zh-Hant": "正在處理…", "zh-HK": "正在處理…", "zh-TW": "正在處理…",
            ],
            "Running": [
                "en": "Running", "zh-Hans": "执行中",
                "zh-Hant": "執行中", "zh-HK": "執行中", "zh-TW": "執行中",
            ],
            "Completed after %lld steps": [
                "en": "Completed after %lld steps", "zh-Hans": "执行了%lld个步骤",
                "zh-Hant": "執行了%lld個步驟", "zh-HK": "執行了%lld個步驟",
                "zh-TW": "執行了%lld個步驟",
            ],
            "%lld steps": [
                "en": "%lld steps", "zh-Hans": "%lld个步骤",
                "zh-Hant": "%lld個步驟", "zh-HK": "%lld個步驟", "zh-TW": "%lld個步驟",
            ],
            "%llds": [
                "en": "%llds", "zh-Hans": "%lld秒", "zh-Hant": "%lld秒",
                "zh-HK": "%lld秒", "zh-TW": "%lld秒",
            ],
            "%lldm": [
                "en": "%lldm", "zh-Hans": "%lld分钟", "zh-Hant": "%lld分鐘",
                "zh-HK": "%lld分鐘", "zh-TW": "%lld分鐘",
            ],
            "%lldh": [
                "en": "%lldh", "zh-Hans": "%lld小时", "zh-Hant": "%lld小時",
                "zh-HK": "%lld小時", "zh-TW": "%lld小時",
            ],
            "%lldh %lldm": [
                "en": "%lldh %lldm", "zh-Hans": "%lld小时%lld分钟", "zh-Hant": "%lld小時%lld分鐘",
                "zh-HK": "%lld小時%lld分鐘", "zh-TW": "%lld小時%lld分鐘",
            ],
        ]

        for language in Self.languages {
            let table = try Self.compiledStrings(language: language)
            for (key, translations) in expected {
                #expect(
                    table[key] == translations[language],
                    "\(language) 下 \(key) 译文缺失或不符，Brief 界面会回退到其它语言"
                )
            }
        }
    }

    // MARK: - Helpers

    private static func disclosureTitle(
        startedAt: Date,
        endedAt: Date?,
        state: AgentLoopState,
        acceptsLiveActivity: Bool,
        now: Date,
        resolve: (String) -> String
    ) -> String {
        let conversationID = UUID()
        let turnID = UUID()
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "继续",
            createdAt: startedAt
        )
        let call = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: startedAt.addingTimeInterval(1),
            turnID: turnID,
            toolCalls: [
                MessageToolCall(id: "c1", name: "search", arguments: "{}", displayDescription: "搜索")
            ]
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: startedAt,
            endedAt: endedAt,
            state: state
        )
        let summary = AgentTurnSummaryBuilder()
            .build(records: [record], messages: [user, call])
            .first!
        let item = AgentTurnPresentationItem(
            recorded: summary,
            acceptsLiveActivity: acceptsLiveActivity
        )
        return AgentTurnVM.processDisclosureTitle(
            item: item,
            userMessages: [user],
            processMessages: [call],
            now: now,
            resolve: resolve
        )
    }

    private static func compiledStrings(language: String) throws -> [String: String] {
        let bundle = pluginLocalization.bundle
        let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
    }
}
