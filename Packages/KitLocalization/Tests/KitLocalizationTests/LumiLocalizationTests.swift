import Foundation
import Testing
@testable import KitLocalization

@Suite("LumiLocalization")
struct LumiLocalizationTests {
    @Test("returns key when bundle has no localization resources")
    func returnsKeyWhenMissingResources() {
        let bundle = Bundle(for: BundleFinder.self)
        #expect(LumiLocalization.string("Missing Key", bundle: bundle) == "Missing Key")
    }

    @Test("returns key for missing xcstrings entry")
    func returnsKeyForMissingCatalogEntry() {
        let bundle = Bundle(for: BundleFinder.self)
        let locale = Locale(identifier: "en")
        #expect(LumiLocalization.string("__nonexistent_key__", bundle: bundle, locale: locale) == "__nonexistent_key__")
    }

    @Test("normalizeLanguageID unifies Chinese variants")
    func normalizeChineseVariants() {
        #expect(LumiLocalization.normalizeLanguageID("zh-CN") == "zh-Hans")
        #expect(LumiLocalization.normalizeLanguageID("zh_Hans") == "zh-Hans")
        #expect(LumiLocalization.normalizeLanguageID("zh") == "zh-Hans")
        #expect(LumiLocalization.normalizeLanguageID("zh-HK") == "zh-HK")
        #expect(LumiLocalization.normalizeLanguageID("zh-TW") == "zh-TW")
        #expect(LumiLocalization.normalizeLanguageID("zh-MO") == "zh-Hant")
        #expect(LumiLocalization.normalizeLanguageID("zh-Hant-TW") == "zh-Hant")
    }

    @Test("normalizeLanguageID collapses English and leaves others intact")
    func normalizeEnglishAndPassthrough() {
        #expect(LumiLocalization.normalizeLanguageID("en-US") == "en")
        #expect(LumiLocalization.normalizeLanguageID("fr") == "fr")
        #expect(LumiLocalization.normalizeLanguageID("ja_JP") == "ja-JP")
    }

    @Test("variantFallbacks orders Traditional Chinese scripts")
    func traditionalFallbacks() {
        #expect(LumiLocalization.variantFallbacks(for: "zh-Hant") == ["zh-Hant", "zh-TW", "zh-HK"])
        #expect(LumiLocalization.variantFallbacks(for: "zh-TW") == ["zh-TW", "zh-Hant", "zh-HK"])
        #expect(LumiLocalization.variantFallbacks(for: "zh-HK") == ["zh-HK", "zh-Hant", "zh-TW"])
        #expect(LumiLocalization.variantFallbacks(for: "en") == ["en"])
    }
}

private final class BundleFinder {}
