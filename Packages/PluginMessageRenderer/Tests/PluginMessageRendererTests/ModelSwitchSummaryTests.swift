import Foundation
import Testing
@testable import PluginMessageRenderer

/// 模型切换时间线主行的文案投影。
///
/// 回归 #907：模型名相同、供应商不同时，主行若只显示模型名会变成
/// `gpt-5 → gpt-5`，用户看不出这是一次真实的路由变化。
/// 回归 #905：摘要片段必须经本地化解析，不能把中文写死在代码里。
@Suite("Model switch summary")
struct ModelSwitchSummaryTests {
    /// 测试内固定为恒等解析，避免依赖宿主机首选语言。
    private static func identity(_ value: String) -> String { value }

    @Test("同模型跨供应商时主行保留供应商（回归 #907）")
    func sameModelAcrossProvidersKeepsProviders() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: "airouter",
            toModelName: "gpt-5",
            resolve: Self.identity
        )

        #expect(summary == "openai · gpt-5 → airouter · gpt-5")
    }

    @Test("同模型跨供应商时两端标签都带供应商")
    func labelsPrefixProvidersOnlyWhenDisambiguating() {
        let labels = ModelSwitchSummary.labels(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: "airouter",
            toModelName: "gpt-5",
            resolve: Self.identity
        )

        #expect(labels.source == "openai · gpt-5")
        #expect(labels.target == "airouter · gpt-5")
    }

    @Test("模型名不同时保持紧凑文案，不追加供应商")
    func differentModelsStayCompact() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: "openai",
            toModelName: "gpt-4o",
            resolve: Self.identity
        )

        #expect(summary == "gpt-5 → gpt-4o")
    }

    @Test("同供应商同名模型仍按模型名展示")
    func sameProviderKeepsModelOnlyLabels() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: "openai",
            toModelName: "gpt-5",
            resolve: Self.identity
        )

        #expect(summary == "gpt-5 → gpt-5")
    }

    @Test("缺少任一供应商时不拼接半边供应商")
    func missingProviderDoesNotPrefix() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: nil,
            toModelName: "gpt-5",
            resolve: Self.identity
        )

        #expect(summary == "gpt-5 → gpt-5")
    }

    @Test("首次选择模型时只显示切换后的模型")
    func firstSelectionHasNoSource() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: nil,
            fromModelName: nil,
            toProviderID: "openai",
            toModelName: "gpt-5",
            resolve: Self.identity
        )

        #expect(summary == "Switched to gpt-5")
    }

    @Test("只有供应商 ID 时退回显示供应商")
    func providerOnlyFallsBackToIDs() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: nil,
            toProviderID: "airouter",
            toModelName: nil,
            resolve: Self.identity
        )

        #expect(summary == "openai → airouter")
    }

    /// 回归 #905：首次选择的前缀与未知模型兜底都必须来自解析器，
    /// 否则英文界面会继续显示「切换到」「未知模型」。
    @Test("摘要片段经过注入的本地化解析（回归 #905）")
    func summaryUsesInjectedLocalization() {
        let resolved: (String) -> String = { "[\($0)]" }

        let first = ModelSwitchSummary.summaryText(
            fromProviderID: nil,
            fromModelName: nil,
            toProviderID: "openai",
            toModelName: "gpt-5",
            resolve: resolved
        )
        #expect(first == "[Switched to %@]".replacingOccurrences(of: "%@", with: "gpt-5"))

        let labels = ModelSwitchSummary.labels(
            fromProviderID: nil,
            fromModelName: nil,
            toProviderID: nil,
            toModelName: nil,
            resolve: resolved
        )
        #expect(labels.target == "[Unknown model]")
    }

    /// 回归 #905：主行、详情弹层与辅助功能用到的词条必须在编译产物里
    /// 对每种受支持语言都有译文，否则英文界面会回退到中文。
    @Test("模型切换词条在所有规范语言下都有译文（回归 #905）")
    func switchLabelsHaveTranslationsInCompiledBundle() throws {
        let expected: [String: [String: String]] = [
            "Model Switch": [
                "en": "Model Switch", "zh-Hans": "模型切换", "zh-Hant": "模型切換",
                "zh-HK": "模型切換", "zh-TW": "模型切換",
            ],
            "Model switch: %@": [
                "en": "Model switch: %@", "zh-Hans": "模型切换：%@", "zh-Hant": "模型切換：%@",
                "zh-HK": "模型切換：%@", "zh-TW": "模型切換：%@",
            ],
            "From": [
                "en": "From", "zh-Hans": "切换前", "zh-Hant": "切換前",
                "zh-HK": "切換前", "zh-TW": "切換前",
            ],
            "Original Provider": [
                "en": "Original Provider", "zh-Hans": "原供应商", "zh-Hant": "原供應商",
                "zh-HK": "原供應商", "zh-TW": "原供應商",
            ],
            "To": [
                "en": "To", "zh-Hans": "切换后", "zh-Hant": "切換後",
                "zh-HK": "切換後", "zh-TW": "切換後",
            ],
            "New Provider": [
                "en": "New Provider", "zh-Hans": "新供应商", "zh-Hant": "新供應商",
                "zh-HK": "新供應商", "zh-TW": "新供應商",
            ],
            "Time": [
                "en": "Time", "zh-Hans": "时间", "zh-Hant": "時間",
                "zh-HK": "時間", "zh-TW": "時間",
            ],
            "Tap to view model switch details": [
                "en": "Tap to view model switch details", "zh-Hans": "点击查看模型切换详情",
                "zh-Hant": "點按檢視模型切換詳情", "zh-HK": "點按檢視模型切換詳情",
                "zh-TW": "點按檢視模型切換詳情",
            ],
            "Switched to %@": [
                "en": "Switched to %@", "zh-Hans": "已切换到 %@", "zh-Hant": "已切換到 %@",
                "zh-HK": "已切換到 %@", "zh-TW": "已切換到 %@",
            ],
            "Unknown model": [
                "en": "Unknown model", "zh-Hans": "未知模型", "zh-Hant": "未知模型",
                "zh-HK": "未知模型", "zh-TW": "未知模型",
            ],
        ]

        for language in ["en", "zh-Hans", "zh-Hant", "zh-HK", "zh-TW"] {
            let table = try Self.compiledStrings(language: language)
            for (key, translations) in expected {
                #expect(
                    table[key] == translations[language],
                    "\(language) 下 \(key) 译文缺失或不符，模型切换界面会回退到其它语言"
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
