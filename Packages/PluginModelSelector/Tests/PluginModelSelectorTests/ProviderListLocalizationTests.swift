import Foundation
import Testing
@testable import PluginModelSelector

@Suite("ProviderListLocalization")
struct ProviderListLocalizationTests {
    /// 回归 #906：中转站分组标题必须经过插件本地化解析，而不是写死中文字面量。
    ///
    /// 用注入的替身解析器断言「文案确实来自解析器」，因为真实解析结果取决于
    /// 宿主首选语言，无法在 CI 上给出与语言无关的期望值。
    @Test("中转站分组标题经过注入的本地化解析（回归 #906）")
    func relaySectionTitleUsesInjectedLocalization() {
        let resolve: (String) -> String = { "localized:\($0)" }

        #expect(
            ProviderListLocalization.relaySectionTitle(resolve: resolve) == "localized:Relay"
        )
    }

    /// 回归 #906：词条必须在编译产物里对每种受支持语言都有译文，
    /// 否则英文界面会显示中文，或中文界面回落成英文 key。
    @Test("中转站分组标题在所有规范语言下都有译文（回归 #906）")
    func relaySectionTitleHasTranslationsInCompiledBundle() throws {
        let expected: [String: String] = [
            "en": "Relay",
            "zh-Hans": "中转站",
            "zh-Hant": "中轉站",
            "zh-HK": "中轉站",
            "zh-TW": "中轉站",
        ]

        for (language, translation) in expected {
            let table = try Self.compiledStrings(language: language)
            #expect(
                table["Relay"] == translation,
                "\(language) 下 Relay 译文缺失或不符，中转站分组标题会回退到其它语言"
            )
        }
    }

    private static func compiledStrings(language: String) throws -> [String: String] {
        let bundle = pluginLocalization.bundle
        let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
    }
}
