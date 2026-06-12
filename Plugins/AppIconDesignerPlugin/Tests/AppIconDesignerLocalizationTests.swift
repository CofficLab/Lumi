import Foundation
import Testing
@testable import AppIconDesignerPlugin

@Suite("App icon designer localization")
struct AppIconDesignerLocalizationTests {
    @Test("loads UI strings from the string catalog")
    func loadsUIStringsFromCatalog() {
        #expect(AppIconDesignerLocalization.string("App Icon Designer") == "App Icon Designer")
        #expect(AppIconDesignerLocalization.format("Opacity %.2f", 0.75) == "Opacity 0.75")
        #expect(AppIconDesignerLocalization.string("Gradient Symbol") == "Gradient Symbol")
    }

    @Test("ships translations for supported languages")
    func shipsTranslationsForSupportedLanguages() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PluginAppIconDesigner/Resources/AppIconDesigner.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])
        let requiredLanguages = ["en", "zh-Hans", "zh-HK"]

        for (key, value) in strings {
            let entry = try #require(value as? [String: Any], "Invalid string catalog entry for \(key)")
            let localizations = try #require(entry["localizations"] as? [String: Any], "Missing localizations for \(key)")

            for language in requiredLanguages {
                let localized = try #require(localizations[language] as? [String: Any], "Missing \(language) localization for \(key)")
                let stringUnit = try #require(localized["stringUnit"] as? [String: Any], "Missing string unit for \(key) \(language)")
                let value = try #require(stringUnit["value"] as? String, "Missing localized value for \(key) \(language)")
                #expect(!value.isEmpty)
            }
        }
    }
}
