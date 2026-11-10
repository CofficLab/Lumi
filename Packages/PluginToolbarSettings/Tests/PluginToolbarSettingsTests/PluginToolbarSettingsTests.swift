import Foundation
import KernelCore
import ProviderToolbar
import SwiftUI
import Testing
@testable import PluginToolbarSettings

/// SettingsToolbarPlugin 的基础验证。
@Suite("PluginToolbarSettings")
@MainActor
struct PluginToolbarSettingsTests {

    @Test("onBoot 在工具栏右侧注册设置按钮")
    func onBootRegistersSettingsButton() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = SettingsToolbarPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(toolbar.toolbarItems.count == 1)
        let item = toolbar.toolbarItems[0]
        #expect(item.id == "settings")
        // 宿主 `DefaultToolbarProviding` 直接把这个 title 用作 `.help(...)`，
        // 即按钮 tooltip，因此必须与本包本地化解析结果一致（#922）。
        #expect(item.title == pluginLocalization.string("Settings"))
        #expect(item.placement == .trailing)

        // 按钮视图可渲染
        #expect(type(of: item.makeView()) == AnyView.self)
    }

    @Test("onBoot 追加语义不覆盖已有项")
    func onBootAppendsToExistingItems() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        toolbar.registerToolbarItems([
            ToolbarItem(id: "run", title: "Run", placement: .leading) { Text("run") },
        ])
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = SettingsToolbarPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(toolbar.toolbarItems.count == 2)
        #expect(toolbar.toolbarItems.contains(where: { $0.id == "settings" }))
    }

    @Test("工具栏未注册时 onBoot 优雅降级")
    func onBootNoOpsWithoutToolbar() throws {
        let kernel = KernelCoreContainer()
        let plugin = SettingsToolbarPlugin()

        // 不应抛错
        try plugin.onBoot(kernel: kernel)
    }

    @Test("插件可经 kernel.start 启动并注册按钮")
    func startViaKernelBootsPlugin() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = SettingsToolbarPlugin()
        try kernel.start(plugins: [plugin])

        #expect(kernel.isPluginRegistered(id: plugin.id))
        #expect(toolbar.toolbarItems.count == 1)
        #expect(toolbar.toolbarItems[0].id == "settings")
    }

    /// 回归 #922：按钮标题必须经过本地化解析，而不是写死中文字面量。
    ///
    /// 用注入的替身解析器断言「标题确实来自解析器」，因为真实解析结果取决于
    /// 宿主首选语言，无法在 CI 上给出与语言无关的期望值。
    @Test("设置按钮标题经过本地化解析（回归 #922）")
    func settingsTitleUsesInjectedLocalization() {
        let item = SettingsToolbarPlugin.makeSettingsToolbarItem { key in
            "localized:\(key)"
        }

        #expect(item.title == "localized:Settings")
    }

    /// 回归 #922：`Settings` 词条必须在编译产物里对每种受支持语言都有译文，
    /// 否则英文界面会显示中文，或中文界面回落成英文 key。
    @Test("Settings 词条在所有规范语言下都有译文（回归 #922）")
    func settingsTitleHasTranslationsInCompiledBundle() throws {
        let expected: [String: String] = [
            "en": "Settings",
            "zh-Hans": "设置",
            "zh-Hant": "設定",
            "zh-HK": "設定",
            "zh-TW": "設定",
        ]

        for (language, translation) in expected {
            let table = try Self.compiledStrings(language: language)
            #expect(
                table["Settings"] == translation,
                "\(language) 下 Settings 译文缺失或不符，tooltip 会回退到其它语言"
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
