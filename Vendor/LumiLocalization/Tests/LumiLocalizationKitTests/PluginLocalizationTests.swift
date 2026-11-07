import Foundation
import Testing
@testable import LumiLocalizationKit

@Suite("PluginLocalization Service")
struct PluginLocalizationTests {

    /// 构造带 `en.lproj/Localizable.strings` 与 `zh-Hans` catalog 条目的临时 bundle。
    private func makeFixtureBundle() throws -> Bundle {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginLocalizationFixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let enDir = dir.appendingPathComponent("en.lproj")
        try FileManager.default.createDirectory(at: enDir, withIntermediateDirectories: true)
        try "greeting = \"Hello\";\n".write(
            to: enDir.appendingPathComponent("Localizable.strings"),
            atomically: true,
            encoding: .utf8
        )

        let catalog: [String: Any] = [
            "sourceLanguage": "en",
            "version": "1.0",
            "strings": [
                "title": [
                    "localizations": [
                        "zh-Hans": ["stringUnit": ["state": "translated", "value": "标题"]],
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

    @Test("服务按 bundle 解析 catalog 条目")
    func resolvesFromCatalog() throws {
        let service = PluginLocalization(bundle: try makeFixtureBundle())

        #expect(service.string("title", locale: Locale(identifier: "zh-Hans")) == "标题")
    }

    @Test("服务按 bundle 解析 lproj 条目")
    func resolvesFromLproj() throws {
        let service = PluginLocalization(bundle: try makeFixtureBundle())

        #expect(service.string("greeting") == "Hello")
    }

    @Test("未命中时回退为原始 key")
    func fallsBackToKey() throws {
        let service = PluginLocalization(bundle: try makeFixtureBundle())

        #expect(service.string("__absent__") == "__absent__")
    }

    @Test("自定义 table 生效")
    func customTable() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginLocalizationTable-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enDir = dir.appendingPathComponent("en.lproj")
        try FileManager.default.createDirectory(at: enDir, withIntermediateDirectories: true)
        try "custom = \"Custom Table\";\n".write(
            to: enDir.appendingPathComponent("Custom.strings"),
            atomically: true,
            encoding: .utf8
        )
        let bundle = try #require(Bundle(path: dir.path))

        let service = PluginLocalization(bundle: bundle, table: "Custom")

        #expect(service.string("custom") == "Custom Table")
    }
}
