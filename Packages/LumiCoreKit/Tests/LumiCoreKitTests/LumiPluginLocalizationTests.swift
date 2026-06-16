import Foundation
import Testing
@testable import LumiCoreKit

@Suite("Lumi plugin localization")
struct LumiPluginLocalizationTests {
    @Test("returns key when bundle has no localization resources")
    func returnsKeyWhenMissingResources() {
        let bundle = Bundle(for: BundleFinder.self)
        #expect(LumiPluginLocalization.string("Missing Key", bundle: bundle) == "Missing Key")
    }

    @Test("loads zh-Hans strings from xcstrings catalog")
    func loadsZhHansFromCatalog() {
        let locale = Locale(identifier: "zh-Hans")
        let value = LumiPluginLocalization.string(
            "about.section.howItWorks",
            bundle: Bundle.module,
            locale: locale
        )
        #expect(value == "工作原理")
    }

    @Test("loads zh-HK strings from xcstrings catalog")
    func loadsZhHKFromCatalog() {
        let locale = Locale(identifier: "zh-HK")
        let value = LumiPluginLocalization.string(
            "about.section.tips",
            bundle: Bundle.module,
            locale: locale
        )
        #expect(value == "使用提示")
    }

    @Test("loads zh-TW strings from xcstrings catalog")
    func loadsZhTWFromCatalog() {
        let locale = Locale(identifier: "zh-TW")
        let value = LumiPluginLocalization.string(
            "about.section.tips",
            bundle: Bundle.module,
            locale: locale
        )
        #expect(value == "使用提示")
    }
}

private final class BundleFinder {}
