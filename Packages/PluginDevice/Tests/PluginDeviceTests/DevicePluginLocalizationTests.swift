import Foundation
import KernelCore
import ProviderActivityBar
import ProviderDocsView
import ProviderMenuBar
import Testing
@testable import PluginDevice

/// Device 插件注册到文档、活动栏与菜单栏的入口标题。
///
/// ## 为什么要有这组用例
///
/// 这些标题曾写死成「设备信息」「内存」两个字面量，绕过了插件本地化服务，
/// 英文界面启用 Device 后仍显示中文（#900）。注册链依赖真实的 kernel 与各
/// provider，无法通过渲染视图断言，因此插件提供 `localize` 注入点：测试用
/// marker 解析器构造插件，直接检查注册结果里的标题。
@Suite("DevicePluginLocalization")
@MainActor
struct DevicePluginLocalizationTests {
    @Test("文档、活动栏与菜单标题经过注入的本地化解析（回归 #900）")
    func registrationTitlesUseInjectedLocalization() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        let activityBar = DefaultActivityBarProviding()
        let menuBar = DefaultMenuBarProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any MenuBarProviding).self, menuBar)

        let plugin = DevicePlugin(localize: { "localized:\($0)" })
        try kernel.start(plugins: [plugin])
        defer { try? kernel.stop() }
        // Device 默认停用：onBoot 的 ActivityBar / 菜单栏贡献在启用后才注册。
        try await kernel.enablePlugin(id: plugin.id)

        #expect(docs.aboutEntries.map(\.name) == ["localized:Device Info"])
        #expect(docs.manualEntries.map(\.name) == ["localized:Device Info"])

        let entry = try #require(activityBar.items.first { $0.id == "\(plugin.id).entry" })
        #expect(entry.title == "localized:Device Info")

        let metrics = try #require(menuBar.contentItems.first { $0.id == "\(plugin.id).metrics" })
        #expect(metrics.title == "localized:Device Info")

        let memory = try #require(menuBar.popupItems.first { $0.id == "\(plugin.id).memory" })
        #expect(memory.title == "localized:Memory")
    }

    @Test("Device Info 与 Memory 词条在所有规范语言下都有译文（回归 #900）")
    func entryLabelsHaveTranslationsInCompiledBundle() throws {
        let expected: [String: [String: String]] = [
            "Device Info": [
                "en": "Device Info",
                "zh-Hans": "设备信息",
                "zh-Hant": "設備資訊",
                "zh-HK": "設備資訊",
                "zh-TW": "設備資訊",
            ],
            "Memory": [
                "en": "Memory",
                "zh-Hans": "内存",
                "zh-Hant": "記憶體",
                "zh-HK": "記憶體",
                "zh-TW": "記憶體",
            ],
        ]

        for (key, translations) in expected {
            for (language, translation) in translations {
                let table = try Self.compiledStrings(language: language)
                #expect(
                    table[key] == translation,
                    "\(language) 下 \(key) 译文缺失或不符，入口标题会回退成其它语言"
                )
            }
        }
    }

    private static func compiledStrings(language: String) throws -> [String: String] {
        let bundle = pluginLocalization.bundle
        let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
    }
}
