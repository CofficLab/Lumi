import Foundation
import Testing
@testable import VideoConverterPlugin

@Suite("Video converter localization")
struct VideoConverterLocalizationTests {
    @Test("plugin bundle includes localized strings catalog")
    func pluginBundleIncludesLocalizedStringsCatalog() {
        let hasCatalog = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") != nil
        let hasCompiledStrings = Bundle.module.path(forResource: "zh-Hans", ofType: "lproj") != nil
        #expect(hasCatalog || hasCompiledStrings)
    }

    @Test("string catalog defines required languages")
    func stringCatalogDefinesRequiredLanguages() throws {
        let strings = try loadCatalogStrings()
        let requiredLanguages = ["en", "zh-Hans", "zh-HK", "zh-TW", "zh-Hant"]

        for (key, value) in strings {
            let entry = try #require(value as? [String: Any], "Invalid entry for \(key)")
            guard let localizations = entry["localizations"] as? [String: Any] else { continue }
            for language in requiredLanguages {
                #expect(localizations[language] != nil, "Missing \(language) for \(key)")
            }
        }
    }

    @Test("string catalog includes localized display strings")
    func stringCatalogIncludesLocalizedDisplayStrings() throws {
        let strings = try loadCatalogStrings()

        try expectCatalogValue(strings, key: "Video Converter", language: "en", value: "Video Converter")
        try expectCatalogValue(strings, key: "Video Converter", language: "zh-Hans", value: "视频转换器")
        try expectCatalogValue(strings, key: "Video Converter", language: "zh-HK", value: "影片轉換器")
        try expectCatalogValue(strings, key: "Video Converter", language: "zh-TW", value: "影片轉換器")
        try expectCatalogValue(strings, key: "Convert", language: "zh-Hans", value: "转换")
        try expectCatalogValue(
            strings,
            key: "Drag & drop a video file here",
            language: "zh-HK",
            value: "將影片檔案拖放到此處"
        )
    }

    private func loadCatalogStrings() throws -> [String: Any] {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(json["strings"] as? [String: Any])
    }

    private func expectCatalogValue(
        _ strings: [String: Any],
        key: String,
        language: String,
        value: String
    ) throws {
        let entry = try #require(strings[key] as? [String: Any], "Missing catalog entry for \(key)")
        let localizations = try #require(entry["localizations"] as? [String: Any])
        let localization = try #require(localizations[language] as? [String: Any])
        let unit = try #require(localization["stringUnit"] as? [String: Any])
        #expect(unit["value"] as? String == value)
    }
}
