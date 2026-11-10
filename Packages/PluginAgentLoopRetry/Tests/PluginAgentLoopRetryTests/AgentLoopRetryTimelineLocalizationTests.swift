import Foundation
import ProviderAgentLoop
import ProviderMessage
import Testing
@testable import PluginAgentLoopRetry

/// 自动重试时间线消息正文的本地化。
///
/// 回归 #895：消息正文必须按当前界面语言生成，英文界面不能写入中文。
@Suite("Agent loop retry timeline localization")
struct AgentLoopRetryTimelineLocalizationTests {
    @Test("时间线正文经过注入的本地化解析（回归 #895）")
    func messageContentUsesInjectedLocalization() {
        let failure = AgentLoopFailure(
            kind: .network,
            message: "连接被重置",
            providerID: "openai",
            modelName: "gpt-5",
            httpStatusCode: 503
        )
        let resolve: (String) -> String = { "[\($0)]" }

        let message = AgentLoopRetryTimeline.message(
            conversationID: UUID(),
            failedTurnID: UUID(),
            attempt: 2,
            maxAttempts: 3,
            failure: failure,
            resolve: resolve
        )

        #expect(message.content == "[Retrying (2/3): 连接被重置]")
        #expect(message.metadata[MessageTimelineEvent.agentLoopRetryAttemptKey] == "2")
        #expect(message.metadata[MessageTimelineEvent.agentLoopRetryReasonKey] == "连接被重置")
    }

    /// 回归 #895：正文词条必须在编译产物里对每种受支持语言都有译文。
    @Test("时间线正文词条在所有规范语言下都有译文（回归 #895）")
    func messageContentHasTranslationsInCompiledBundle() throws {
        let expected: [String: [String: String]] = [
            "Retrying (%lld/%lld): %@": [
                "en": "Retrying (%lld/%lld): %@",
                "zh-Hans": "正在重试（%lld/%lld）：%@",
                "zh-Hant": "正在重試（%lld/%lld）：%@",
                "zh-HK": "正在重試（%lld/%lld）：%@",
                "zh-TW": "正在重試（%lld/%lld）：%@",
            ],
        ]

        for language in ["en", "zh-Hans", "zh-Hant", "zh-HK", "zh-TW"] {
            let table = try Self.compiledStrings(language: language)
            for (key, translations) in expected {
                #expect(
                    table[key] == translations[language],
                    "\(language) 下 \(key) 译文缺失或不符，重试时间线会回退到其它语言"
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
