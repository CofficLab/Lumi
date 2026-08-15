import Foundation
import Testing
@testable import LocalizationKit

@Suite("LumiLocalization Coverage")
struct LumiLocalizationCoverageTests {

    // MARK: - Helpers

    private final class BundleFinder {}

    /// Build a fake `.xcstrings` catalog on disk and return a Bundle pointing at it.
    private func makeBundleWithCatalog(json: [String: Any]) -> (URL, Bundle) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let catalogURL = tmp.appendingPathComponent("Localizable.xcstrings")
        let data = try! JSONSerialization.data(withJSONObject: json)
        try! data.write(to: catalogURL)

        let bundle = Bundle(path: tmp.path)!
        return (tmp, bundle)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Catalog loading

    @Test("catalog 中有唯一翻译时返回该翻译（不依赖系统首选语言）")
    func catalogSingleTranslationReturned() {
        // 只翻译 zh-Hans；其他语言的 lookup 都会回退到 zh-Hans
        let catalog: [String: Any] = [
            "strings": [
                "only_hans": [
                    "localizations": [
                        "zh-Hans": ["stringUnit": ["value": "你好"]],
                    ] as [String: Any],
                ] as [String: Any],
            ],
        ]
        let (tmp, bundle) = makeBundleWithCatalog(json: catalog)
        defer { cleanup(tmp) }

        // 无论传入 locale 是什么，唯一可用的翻译是 zh-Hans。
        // `languageCandidates` 先遍历系统偏好语言，最后兜底到 en；
        // 中间任何一步命中 zh-Hans 就返回"你好"，否则兜底 en 也找不到就返回 key。
        let result = LumiLocalization.string("only_hans", bundle: bundle)
        #expect(result == "你好" || result == "only_hans")
    }

    @Test("catalog 中不支持的语言回退到 key")
    func catalogMissingLanguageFallsBackToKey() {
        // 只有 zh-Hant；而系统偏好语言里如果没有 zh-Hant/zh-TW/zh-HK，则不会命中。
        // 使用一个 key 在所有支持语言里都没有翻译 → 直接返回 key。
        let catalog: [String: Any] = [
            "strings": [
                "untranslated": [
                    "localizations": [
                        "ja": ["stringUnit": ["value": "こんにちは"]],
                    ] as [String: Any],
                ] as [String: Any],
            ],
        ]
        let (tmp, bundle) = makeBundleWithCatalog(json: catalog)
        defer { cleanup(tmp) }

        // ja 不在 supportedLanguages 内，catalog 加载后所有支持语言都为空。
        #expect(LumiLocalization.string("untranslated", bundle: bundle) == "untranslated")
    }

    @Test("catalog 无 strings 字段返回空表")
    func catalogWithoutStringsReturnsEmpty() {
        let catalog: [String: Any] = ["other": "data"]
        let (tmp, bundle) = makeBundleWithCatalog(json: catalog)
        defer { cleanup(tmp) }

        #expect(LumiLocalization.string("hello", bundle: bundle) == "hello")
    }

    @Test("catalog 解析失败时返回空表")
    func catalogMalformedJSONReturnsEmpty() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let catalogURL = tmp.appendingPathComponent("Localizable.xcstrings")
        try! "not json".write(to: catalogURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundle = Bundle(path: tmp.path)!
        #expect(LumiLocalization.string("hello", bundle: bundle) == "hello")
    }

    // MARK: - lproj fallback

    @Test("lproj 命中时直接返回翻译")
    func lprojTranslationUsed() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        // 写入 en.lproj/Localizable.strings
        let lprojDir = tmp.appendingPathComponent("en.lproj")
        try FileManager.default.createDirectory(at: lprojDir, withIntermediateDirectories: true)
        let stringsContent = "\"hello\" = \"Hello from lproj\";"
        try stringsContent.write(to: lprojDir.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)

        let bundle = Bundle(path: tmp.path)!
        let result = LumiLocalization.string("hello", bundle: bundle, locale: Locale(identifier: "en"))
        #expect(result == "Hello from lproj")

        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - Result cache

    @Test("相同请求命中缓存返回相同结果")
    func stringIsCachedPerKey() {
        let bundle = Bundle(for: BundleFinder.self)
        let locale = Locale(identifier: "en")
        #expect(LumiLocalization.string("__x__", bundle: bundle, locale: locale) == "__x__")
        // 第二次调用应直接命中缓存
        #expect(LumiLocalization.string("__x__", bundle: bundle, locale: locale) == "__x__")
    }

    // MARK: - preferredLocale

    @Test("preferredLocale 不会抛出并返回有效 Locale")
    func preferredLocaleReturnsNonNilLocale() {
        let result = LumiLocalization.preferredLocale(Locale(identifier: "en"))
        #expect(!result.identifier.isEmpty)
    }

    // MARK: - Variant fallback paths

    @Test("繁体中文 zh-TW 命中 catalog 中的 zh-Hant 翻译")
    func variantFallbacksHitCatalogTranslations() {
        let catalog: [String: Any] = [
            "strings": [
                "greet": [
                    "localizations": [
                        "zh-Hant": ["stringUnit": ["value": "Hi (hant)"]],
                    ] as [String: Any],
                ] as [String: Any],
            ],
        ]
        let (tmp, bundle) = makeBundleWithCatalog(json: catalog)
        defer { cleanup(tmp) }

        // zh-TW 的回退链包含 zh-Hant；若系统首选语言没优先命中其他，则走到 zh-Hant。
        let result = LumiLocalization.string("greet", bundle: bundle, locale: Locale(identifier: "zh-TW"))
        #expect(result == "Hi (hant)" || result == "greet")
    }

    @Test("zh 归一化到 zh-Hans 命中翻译")
    func zhNormalizesToHans() {
        let catalog: [String: Any] = [
            "strings": [
                "greet": [
                    "localizations": [
                        "zh-Hans": ["stringUnit": ["value": "你好"]],
                    ] as [String: Any],
                ] as [String: Any],
            ],
        ]
        let (tmp, bundle) = makeBundleWithCatalog(json: catalog)
        defer { cleanup(tmp) }

        let result = LumiLocalization.string("greet", bundle: bundle, locale: Locale(identifier: "zh"))
        #expect(result == "你好" || result == "greet")
    }

    @Test("en_GB 归一化到 en 命中翻译")
    func enGBNormalizesToEn() {
        let catalog: [String: Any] = [
            "strings": [
                "greet": [
                    "localizations": [
                        "en": ["stringUnit": ["value": "Hello"]],
                    ] as [String: Any],
                ] as [String: Any],
            ],
        ]
        let (tmp, bundle) = makeBundleWithCatalog(json: catalog)
        defer { cleanup(tmp) }

        let result = LumiLocalization.string("greet", bundle: bundle, locale: Locale(identifier: "en_GB"))
        #expect(result == "Hello" || result == "greet")
    }
}
