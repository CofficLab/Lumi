import Foundation
import Testing
@testable import LumiLocalizationKit

@Suite("LumiLocalization Fixtures")
struct LumiLocalizationFixtureTests {

    /// 构造带 `en.lproj/Localizable.strings` 与 `Localizable.xcstrings` 的临时 bundle。
    /// 每个用例独立目录，避免结果缓存跨用例污染。
    private func makeFixtureBundle() throws -> Bundle {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiLocalizationFixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 1) en.lproj / Localizable.strings
        let enDir = dir.appendingPathComponent("en.lproj")
        try FileManager.default.createDirectory(at: enDir, withIntermediateDirectories: true)
        try "lproj_key = \"From LPROJ\";\n".write(
            to: enDir.appendingPathComponent("Localizable.strings"),
            atomically: true,
            encoding: .utf8
        )

        // 2) Localizable.xcstrings：zh-Hans 与 zh-TW 各一条目录条目。
        let catalog: [String: Any] = [
            "sourceLanguage": "en",
            "version": "1.0",
            "strings": [
                "catalog_key": [
                    "localizations": [
                        "zh-Hans": ["stringUnit": ["state": "translated", "value": "来自目录"]],
                    ],
                ],
                "variant_key": [
                    "localizations": [
                        "zh-TW": ["stringUnit": ["state": "translated", "value": "繁體字串"]],
                    ],
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: catalog)
        try data.write(to: dir.appendingPathComponent("Localizable.xcstrings"))

        guard let bundle = Bundle(path: dir.path) else {
            throw TestError.bundleCreationFailed
        }
        return bundle
    }

    private enum TestError: Error {
        case bundleCreationFailed
    }

    // MARK: - 解析路径

    @Test("xcstrings catalog 中的 zh-Hans 条目被解析")
    func resolvesFromCatalog() throws {
        let bundle = try makeFixtureBundle()
        let locale = Locale(identifier: "zh-Hans")

        let value = LumiLocalization.string("catalog_key", bundle: bundle, locale: locale)

        #expect(value == "来自目录")
    }

    @Test("lproj strings 文件中的条目被解析")
    func resolvesFromLproj() throws {
        let bundle = try makeFixtureBundle()

        // lproj_key 只在 en.lproj 中：无论系统偏好顺序如何，都会命中 lproj 查找。
        let value = LumiLocalization.string("lproj_key", bundle: bundle)

        #expect(value == "From LPROJ")
    }

    @Test("catalog 与 lproj 均未命中时返回原始 key")
    func fallsBackToKey() throws {
        let bundle = try makeFixtureBundle()

        #expect(LumiLocalization.string("__absent__", bundle: bundle) == "__absent__")
    }

    @Test("同一 key 重复查询结果稳定（命中缓存）")
    func repeatedLookupIsStable() throws {
        let bundle = try makeFixtureBundle()
        let locale = Locale(identifier: "zh-Hans")

        let first = LumiLocalization.string("catalog_key", bundle: bundle, locale: locale)
        let second = LumiLocalization.string("catalog_key", bundle: bundle, locale: locale)

        #expect(first == "来自目录")
        #expect(second == first)
    }

    // MARK: - 繁体变体回退

    @Test("zh-Hant locale 回退到 zh-TW catalog 条目")
    func traditionalChineseVariantFallback() throws {
        // 若系统语言本身含繁体，locale 参数回退链无法确定性地被验证，跳过。
        let systemHasTraditional = Locale.preferredLanguages.contains {
            $0.hasPrefix("zh-Hant") || $0.hasPrefix("zh-TW") || $0.hasPrefix("zh-HK")
        }
        try #require(!systemHasTraditional, "系统语言已含繁体，跳过变体回退断言")
        let bundle = try makeFixtureBundle()

        let value = LumiLocalization.string(
            "variant_key",
            bundle: bundle,
            locale: Locale(identifier: "zh-Hant")
        )

        // 无 zh-Hant 条目时按回退链 zh-Hant → zh-TW → zh-HK 命中 zh-TW。
        #expect(value == "繁體字串")
    }

    @Test("zh-TW locale 直接命中 zh-TW 条目")
    func traditionalChineseDirectHit() throws {
        let bundle = try makeFixtureBundle()

        let value = LumiLocalization.string(
            "variant_key",
            bundle: bundle,
            locale: Locale(identifier: "zh-TW")
        )

        #expect(value == "繁體字串")
    }

    // MARK: - 损坏输入

    @Test("损坏的 xcstrings 文件回退到原始 key")
    func corruptedCatalogFallsBackToKey() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiLocalizationCorrupt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not-json{{{".utf8).write(to: dir.appendingPathComponent("Localizable.xcstrings"))

        guard let bundle = Bundle(path: dir.path) else {
            throw TestError.bundleCreationFailed
        }

        #expect(LumiLocalization.string("anything", bundle: bundle) == "anything")
    }

    @Test("preferredLocale 对简体中文 locale 返回可解析的标识")
    func preferredLocaleResolves() {
        let locale = LumiLocalization.preferredLocale(Locale(identifier: "zh-Hans"))
        #expect(locale.identifier.isEmpty == false)
    }
}
