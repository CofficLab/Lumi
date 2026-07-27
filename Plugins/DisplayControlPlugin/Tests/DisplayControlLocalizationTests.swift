import Foundation
import Testing
import LumiKernel
@testable import DisplayControlPlugin

@Suite("Display control localization")
struct DisplayControlLocalizationTests {
    @Test("plugin bundle includes localized strings catalog")
    func pluginBundleIncludesLocalizedStringsCatalog() {
        let hasCatalog = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") != nil
        let hasCompiledStrings = Bundle.module.path(forResource: "zh-Hans", ofType: "lproj") != nil
        #expect(hasCatalog || hasCompiledStrings)
    }

    @Test("loads simplified Chinese strings from plugin bundle")
    func loadsSimplifiedChineseStrings() {
        let locale = Locale(identifier: "zh-Hans")
        #expect(LumiPluginLocalization.string("Display Control", bundle: .module, locale: locale) == "显示器控制")
        #expect(LumiPluginLocalization.string("Brightness", bundle: .module, locale: locale) == "亮度")
        #expect(LumiPluginLocalization.string("Restore Defaults", bundle: .module, locale: locale) == "恢复默认值")
        #expect(LumiPluginLocalization.string("Display Control", bundle: .module, locale: Locale(identifier: "zh_CN")) == "显示器控制")
    }

    @Test("string catalog defines required languages")
    func stringCatalogDefinesRequiredLanguages() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])
        let requiredLanguages = ["en", "zh-Hans", "zh-HK", "zh-TW", "zh-Hant"]

        for (key, value) in strings {
            let entry = try #require(value as? [String: Any], "Invalid entry for \(key)")
            guard let localizations = entry["localizations"] as? [String: Any] else { continue }
            for language in requiredLanguages {
                #expect(localizations[language] != nil, "Missing \(language) for \(key)")
            }
        }
    }

    @Test("string catalog includes key display strings")
    func stringCatalogIncludesKeyDisplayStrings() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])

        for key in ["Display Control", "Brightness", "Restore Defaults"] {
            #expect(strings[key] != nil, "Missing catalog entry for \(key)")
        }

        let displayControl = try #require(strings["Display Control"] as? [String: Any])
        let localizations = try #require(displayControl["localizations"] as? [String: Any])
        let zhHans = try #require(localizations["zh-Hans"] as? [String: Any])
        let unit = try #require(zhHans["stringUnit"] as? [String: Any])
        #expect(unit["value"] as? String == "显示器控制")
    }
}
