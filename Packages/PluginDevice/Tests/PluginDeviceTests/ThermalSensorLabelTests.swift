import Foundation
import Testing
@testable import PluginDevice

/// CPU 温度卡片的传感器行标签。
///
/// ## 为什么要有这组用例
///
/// 传感器行曾直接 `String(format: "Sensor %d", ...)`，绕过了插件本地化服务，
/// 于是资源目录里明明有「传感器 %d」的译文，中文界面仍显示英文（#901）。
/// 这里钉住两件事：标签确实经过本地化解析器，且资源在各语言下都有译文。
@Suite("ThermalSensorLabel")
struct ThermalSensorLabelTests {
    @Test("传感器标签经注入的本地化解析并保留下标（回归 #901）")
    func sensorLabelUsesInjectedLocalization() {
        let resolve: (String) -> String = { "localized:\($0)" }

        #expect(
            ThermalSensorLabel.text(index: 3, resolve: resolve) == "localized:Sensor 3"
        )
    }

    @Test("Sensor %d 在编译产物中有对应译文（回归 #901）")
    func sensorLabelHasTranslationsInCompiledBundle() throws {
        let expected: [String: String] = [
            "en": "Sensor %d",
            "zh-Hans": "传感器 %d",
            "zh-HK": "感測器 %d",
            "zh-TW": "感測器 %d",
        ]

        for (language, translation) in expected {
            let table = try Self.compiledStrings(language: language)
            #expect(
                table["Sensor %d"] == translation,
                "\(language) 下 Sensor %d 译文缺失或不符，传感器标签会回退成英文"
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
