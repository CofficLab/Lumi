import Foundation
import Testing
@testable import PluginMessageRenderer

/// 自动重试时间线文案投影。
///
/// 回归 #895：重试状态与详情标签必须经本地化解析，不能把中文写死在视图里。
@Suite("Agent loop retry summary")
struct AgentLoopRetrySummaryTests {
    @Test("状态文案经过注入的本地化解析（回归 #895）")
    func statusUsesInjectedLocalization() {
        let resolve: (String) -> String = { "[\($0)]" }

        let numbered = AgentLoopRetrySummary.statusText(
            attempt: 1,
            maxAttempts: 3,
            resolve: resolve
        )
        #expect(numbered == "[Retrying (1/3)]")

        let bare = AgentLoopRetrySummary.statusText(
            attempt: nil,
            maxAttempts: nil,
            resolve: resolve
        )
        #expect(bare == "[Retrying]")
    }

    @Test("退避文案经过注入的本地化解析（回归 #895）")
    func retryAfterUsesInjectedLocalization() {
        let resolve: (String) -> String = { "[\($0)]" }

        let text = AgentLoopRetrySummary.retryAfterText(seconds: "30", resolve: resolve)
        #expect(text == "[30 seconds before retry]")

        #expect(AgentLoopRetrySummary.retryAfterText(seconds: nil, resolve: resolve) == nil)
        #expect(AgentLoopRetrySummary.retryAfterText(seconds: "soon", resolve: resolve) == nil)
    }

    /// 回归 #895：状态、详情与提示用到的词条必须在编译产物里对每种
    /// 受支持语言都有译文，否则英文界面会回退到中文。
    @Test("自动重试词条在所有规范语言下都有译文（回归 #895）")
    func retryLabelsHaveTranslationsInCompiledBundle() throws {
        let expected: [String: [String: String]] = [
            "Retrying": [
                "en": "Retrying", "zh-Hans": "正在重试", "zh-Hant": "正在重試",
                "zh-HK": "正在重試", "zh-TW": "正在重試",
            ],
            "Retrying (%lld/%lld)": [
                "en": "Retrying (%lld/%lld)", "zh-Hans": "正在重试（%lld/%lld）",
                "zh-Hant": "正在重試（%lld/%lld）", "zh-HK": "正在重試（%lld/%lld）",
                "zh-TW": "正在重試（%lld/%lld）",
            ],
            "Reason": [
                "en": "Reason", "zh-Hans": "原因", "zh-Hant": "原因",
                "zh-HK": "原因", "zh-TW": "原因",
            ],
            "Error Type": [
                "en": "Error Type", "zh-Hans": "错误类型", "zh-Hant": "錯誤類型",
                "zh-HK": "錯誤類型", "zh-TW": "錯誤類型",
            ],
            "HTTP Status Code": [
                "en": "HTTP Status Code", "zh-Hans": "HTTP 状态码", "zh-Hant": "HTTP 狀態碼",
                "zh-HK": "HTTP 狀態碼", "zh-TW": "HTTP 狀態碼",
            ],
            "Wait": [
                "en": "Wait", "zh-Hans": "等待", "zh-Hant": "等待",
                "zh-HK": "等待", "zh-TW": "等待",
            ],
            "%lld seconds before retry": [
                "en": "%lld seconds before retry", "zh-Hans": "%lld 秒后重试",
                "zh-Hant": "%lld 秒後重試", "zh-HK": "%lld 秒後重試",
                "zh-TW": "%lld 秒後重試",
            ],
            "Model": [
                "en": "Model", "zh-Hans": "模型", "zh-Hant": "模型",
                "zh-HK": "模型", "zh-TW": "模型",
            ],
            "Tap to view retry details": [
                "en": "Tap to view retry details", "zh-Hans": "点击查看重试详情",
                "zh-Hant": "點按檢視重試詳情", "zh-HK": "點按檢視重試詳情",
                "zh-TW": "點按檢視重試詳情",
            ],
        ]

        for language in ["en", "zh-Hans", "zh-Hant", "zh-HK", "zh-TW"] {
            let table = try Self.compiledStrings(language: language)
            for (key, translations) in expected {
                #expect(
                    table[key] == translations[language],
                    "\(language) 下 \(key) 译文缺失或不符，自动重试界面会回退到其它语言"
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
