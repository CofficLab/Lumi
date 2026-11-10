import Foundation
import Testing
@testable import PluginDevice

/// Device About 页 Core Capabilities 网格的本地化资源。
///
/// ## 为什么要有这组用例
///
/// 网格里六个功能标题都走 `pluginLocalization.string(...)`，但 `Memory Monitor`
/// 的条目曾整体缺失。解析器找不到词条只能回退成英文 key，中文界面上同一个
/// 网格里就出现五个中文标题夹一个英文标题（#902）。资源文件不会在编译期报错，
/// 只能靠用例把「每个受支持语言都有译文」钉住。
@Suite("DeviceAboutLocalization")
struct DeviceAboutLocalizationTests {
    @Test("Memory Monitor 在所有规范语言下都有译文（回归 #902）")
    func memoryMonitorHasTranslationsInCompiledBundle() throws {
        let expected: [String: String] = [
            "en": "Memory Monitor",
            "zh-Hans": "内存监控",
            "zh-Hant": "記憶體監控",
            "zh-HK": "記憶體監控",
            "zh-TW": "記憶體監控",
        ]

        for (language, translation) in expected {
            let table = try Self.compiledStrings(language: language)
            #expect(
                table["Memory Monitor"] == translation,
                "\(language) 下 Memory Monitor 译文缺失或不符，About 页会回退成英文"
            )
        }
    }

    private static func compiledStrings(language: String) throws -> [String: String] {
        let bundle = pluginLocalization.bundle
        let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
    }
}
