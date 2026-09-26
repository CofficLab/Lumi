import Foundation
import Testing
@testable import KitLocalization

/// 通过构造一个临时 bundle（含 .lproj 与 .xcstrings）验证运行时查找的完整解析路径：
/// lproj 优先于 catalog、catalog 回退、繁体变体回退、未命中返回 key。
@Suite("LumiLocalization 解析路径")
struct LumiLocalizationResolutionTests {

    /// 构造一个临时 bundle 目录并写入 lproj + xcstrings 资源。
    ///
    /// 布局：
    /// ```
    ///   Fake.bundle/
    ///     en.lproj/Localizable.strings        (lproj 优先级证据)
    ///     zh-Hans.lproj/Localizable.strings
    ///     Localizable.xcstrings               (catalog 回退)
    /// ```
    /// 关键设计：
    /// - `shared` 同时存在于 en.lproj 与 en catalog（值不同）→ 断言 lproj 胜出。
    /// - `catalogOnly` 只在 en catalog → 断言 catalog 回退命中。
    /// - `zhOnly` 只在 zh-Hans catalog → 断言中文候选命中。
    /// - `twOnly` 只在 zh-TW catalog → 断言 zh-Hant-TW locale 的变体回退命中 zh-TW。
    private func makeBundle() throws -> Bundle {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("LumiLocTests-\(UUID().uuidString).bundle", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        // en.lproj
        let enLproj = root.appendingPathComponent("en.lproj", isDirectory: true)
        try fm.createDirectory(at: enLproj, withIntermediateDirectories: false)
        try """
        "shared" = "LPROJ_EN";
        "lprojOnly" = "From Lproj";
        """.write(to: enLproj.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)

        // zh-Hans.lproj
        let zhLproj = root.appendingPathComponent("zh-Hans.lproj", isDirectory: true)
        try fm.createDirectory(at: zhLproj, withIntermediateDirectories: false)
        try """
        "zhLprojOnly" = "来自 Lproj";
        """.write(to: zhLproj.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)

        // Localizable.xcstrings（catalog 回退）
        let xcstrings: [String: Any] = [
            "sourceLanguage": "en",
            "strings": [
                "shared": [
                    "localizations": [
                        "en": ["stringUnit": ["state": "translated", "value": "CATALOG_EN"]],
                    ]
                ],
                "catalogOnly": [
                    "localizations": [
                        "en": ["stringUnit": ["state": "translated", "value": "Catalog only en"]],
                    ]
                ],
                "zhOnly": [
                    "localizations": [
                        "zh-Hans": ["stringUnit": ["state": "translated", "value": "中文仅目录"]],
                    ]
                ],
                "twOnly": [
                    "localizations": [
                        "zh-TW": ["stringUnit": ["state": "translated", "value": "臺灣目錄"]],
                    ]
                ],
            ],
            "version": "1.0",
        ]
        let data = try JSONSerialization.data(withJSONObject: xcstrings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: root.appendingPathComponent("Localizable.xcstrings"))

        guard let bundle = Bundle(path: root.path) else {
            throw WorkspaceError.cannotConstructBundle
        }
        return bundle
    }

    private enum WorkspaceError: Error { case cannotConstructBundle }

    @Test("lproj 命中时优先于同名 catalog 条目")
    func lprojBeatsCatalog() throws {
        let bundle = try makeBundle()
        // shared 在 en.lproj=LPROJ_EN，en catalog=CATALOG_EN：lproj 应胜出。
        // zh-Hans 候选不含 shared（无论系统偏好如何都会先落空再落到 en）。
        #expect(LumiLocalization.string("shared", bundle: bundle, locale: Locale(identifier: "en")) == "LPROJ_EN")
    }

    @Test("lproj 未命中时回退到 xcstrings catalog")
    func catalogFallbackWhenLprojMissing() throws {
        let bundle = try makeBundle()
        // catalogOnly 只在 en catalog 中，任何 lproj 都没有它。
        #expect(LumiLocalization.string("catalogOnly", bundle: bundle, locale: Locale(identifier: "en")) == "Catalog only en")
    }

    @Test("zh-Hans catalog 条目按中文 locale 解析")
    func zhHansCatalogResolved() throws {
        let bundle = try makeBundle()
        // zhOnly 只在 zh-Hans catalog。显式传入 zh-Hans locale 使该候选参与查找；
        // en 候选必然 miss，zh-Hans 候选必然命中，与系统偏好无关。
        #expect(LumiLocalization.string("zhOnly", bundle: bundle, locale: Locale(identifier: "zh-Hans")) == "中文仅目录")
    }

    @Test("zh-Hant-TW locale 经变体回退命中 zh-TW catalog")
    func traditionalVariantFallsBackToZHTW() throws {
        let bundle = try makeBundle()
        // twOnly 只在 zh-TW catalog。locale=zh-Hant-TW 归一化为 zh-Hant 后，
        // 变体顺序 zh-Hant → zh-TW → zh-HK，应在 zh-TW 命中。
        #expect(LumiLocalization.string("twOnly", bundle: bundle, locale: Locale(identifier: "zh-Hant-TW")) == "臺灣目錄")
    }

    @Test("lproj 查找在指定语言命中（en 与 zh-Hans 各自的专属 lproj key）")
    func lprojLookupPerLanguage() throws {
        let bundle = try makeBundle()
        // lprojOnly 只在 en.lproj：任何候选链中 en 都会命中它。
        #expect(LumiLocalization.string("lprojOnly", bundle: bundle, locale: Locale(identifier: "en")) == "From Lproj")
        // zhLprojOnly 只在 zh-Hans.lproj（en 候选与 catalog 都没有它）：
        // 显式 locale zh-Hans 使该候选参与查找并命中，与系统偏好无关。
        #expect(LumiLocalization.string("zhLprojOnly", bundle: bundle, locale: Locale(identifier: "zh-Hans")) == "来自 Lproj")
    }

    @Test("lproj 与 catalog 均未命中时原样返回 key")
    func returnsKeyWhenNothingMatches() throws {
        let bundle = try makeBundle()
        #expect(LumiLocalization.string("totally-absent-key", bundle: bundle, locale: Locale(identifier: "en")) == "totally-absent-key")
    }

    @Test("重复查询命中记忆化缓存，结果一致")
    func memoizedCacheReturnsSameValue() throws {
        let bundle = try makeBundle()
        let locale = Locale(identifier: "en")
        let first = LumiLocalization.string("catalogOnly", bundle: bundle, locale: locale)
        let second = LumiLocalization.string("catalogOnly", bundle: bundle, locale: locale)
        #expect(first == second)
        #expect(first == "Catalog only en")
    }

    @Test("preferredLocale 返回非空 locale 且稳定")
    func preferredLocaleIsNonEmpty() {
        let loc = LumiLocalization.preferredLocale()
        #expect(!loc.identifier.isEmpty)
        // 同一入参多次调用结果一致（语言链归一化是确定性的）
        #expect(LumiLocalization.preferredLocale().identifier == loc.identifier)
    }
}
