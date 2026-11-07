import Foundation
import Testing
@testable import LumiLocalizationKit

@Suite("LumiLocalization Additional Coverage")
struct LumiLocalizationAdditionalTests {

    private enum TestError: Error {
        case bundleCreationFailed
    }

    private func makeCatalogBundle(
        directoryName: String,
        catalog: [String: Any]
    ) throws -> Bundle {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(directoryName + "-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: catalog)
        try data.write(to: dir.appendingPathComponent("Localizable.xcstrings"))
        guard let bundle = Bundle(path: dir.path) else {
            throw TestError.bundleCreationFailed
        }
        return bundle
    }

    @Test("zh-HK locale 直接命中 zh-HK catalog 条目")
    func resolvesZhHK() throws {
        let catalog: [String: Any] = [
            "strings": [
                "hk_key": [
                    "localizations": [
                        "zh-HK": ["stringUnit": ["state": "translated", "value": "香港條目"]],
                    ],
                ],
            ],
        ]
        let bundle = try makeCatalogBundle(directoryName: "LumiLocalizationHK", catalog: catalog)

        let value = LumiLocalization.string(
            "hk_key",
            bundle: bundle,
            locale: Locale(identifier: "zh-HK")
        )
        #expect(value == "香港條目")
    }

    @Test("zh-Hant locale 回退链命中 zh-HK 条目")
    func zhHantFallsBackToZhHK() throws {
        let catalog: [String: Any] = [
            "strings": [
                "hk_only": [
                    "localizations": [
                        "zh-HK": ["stringUnit": ["state": "translated", "value": "只有香港"]],
                    ],
                ],
            ],
        ]
        let bundle = try makeCatalogBundle(directoryName: "LumiLocalizationHKFall", catalog: catalog)

        let value = LumiLocalization.string(
            "hk_only",
            bundle: bundle,
            locale: Locale(identifier: "zh-Hant")
        )
        // zh-Hant → zh-TW → zh-HK 回退链命中 zh-HK。
        #expect(value == "只有香港")
    }

    @Test("zh 裸语言标识归一化为 zh-Hans")
    func bareZhNormalizesToHans() throws {
        let catalog: [String: Any] = [
            "strings": [
                "simp_key": [
                    "localizations": [
                        "zh-Hans": ["stringUnit": ["state": "translated", "value": "简体"]],
                    ],
                ],
            ],
        ]
        let bundle = try makeCatalogBundle(directoryName: "LumiLocalizationBareZh", catalog: catalog)

        let value = LumiLocalization.string(
            "simp_key",
            bundle: bundle,
            locale: Locale(identifier: "zh")
        )
        #expect(value == "简体")
    }

    @Test("en locale 命中英文 catalog 条目")
    func resolvesEnglish() throws {
        let catalog: [String: Any] = [
            "strings": [
                "en_key": [
                    "localizations": [
                        "en": ["stringUnit": ["state": "translated", "value": "English Value"]],
                    ],
                ],
            ],
        ]
        let bundle = try makeCatalogBundle(directoryName: "LumiLocalizationEN", catalog: catalog)

        let value = LumiLocalization.string(
            "en_key",
            bundle: bundle,
            locale: Locale(identifier: "en")
        )
        #expect(value == "English Value")
    }

    @Test("preferredLocale 对各 locale 返回非空标识")
    func preferredLocaleVariants() {
        for identifier in ["zh-Hans", "zh-HK", "zh-TW", "zh-Hant", "en", "fr"] {
            let locale = LumiLocalization.preferredLocale(Locale(identifier: identifier))
            #expect(locale.identifier.isEmpty == false, "locale=\(identifier)")
        }
    }

    @Test("无 localizations 字段的 catalog 条目被跳过")
    func skipsEntriesWithoutLocalizations() throws {
        let catalog: [String: Any] = [
            "strings": [
                "no_loc_entry": [
                    // 故意没有 localizations 字段
                ],
                "good_entry": [
                    "localizations": [
                        "en": ["stringUnit": ["state": "translated", "value": "Good"]],
                    ],
                ],
            ],
        ]
        let bundle = try makeCatalogBundle(directoryName: "LumiLocalizationSkip", catalog: catalog)

        // no_loc_entry 应被跳过，返回 key 本身。
        #expect(LumiLocalization.string("no_loc_entry", bundle: bundle, locale: Locale(identifier: "en")) == "no_loc_entry")
        #expect(LumiLocalization.string("good_entry", bundle: bundle, locale: Locale(identifier: "en")) == "Good")
    }
}
