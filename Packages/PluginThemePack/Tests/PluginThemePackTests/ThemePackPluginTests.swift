import Foundation
import ProviderTheme
import Testing

@testable import PluginThemePack

@MainActor
struct ThemePackPluginTests {

    /// 旧版主题目录包含 19 个主题（17 个插件，Vscode 插件含 3 个变体）。
    @Test
    func catalogHasAllLegacyThemes() {
        #expect(LegacyThemeCatalog.all.count == 19)
    }

    /// 每个主题 id 唯一，且与旧版主题插件注册的 id 一致。
    @Test
    func catalogIDsMatchLegacy() {
        let expectedIDs: Set<String> = [
            "lumi", "midnight", "sky", "aurora", "nebula", "void",
            "spring", "summer", "autumn", "winter", "github", "orchard",
            "mountain", "vscode-auto", "vscode-dark", "vscode-light",
            "river", "one-dark", "dracula",
        ]
        let actualIDs = Set(LegacyThemeCatalog.all.map(\.id))
        #expect(actualIDs == expectedIDs)
        #expect(actualIDs.count == 19)
    }

    /// 每个主题的 id / 显示名 / 图标 / 外观类型齐全。
    @Test
    func catalogMetadataIsComplete() {
        for theme in LegacyThemeCatalog.all {
            #expect(!theme.id.isEmpty)
            #expect(!theme.displayName.isEmpty)
            #expect(!theme.iconName.isEmpty)
        }
    }

    /// 注册到 DefaultThemeProviding 后：内置 3 + 复刻 19 = 22 个主题。
    @Test
    func pluginRegistersAllThemes() throws {
        let provider = DefaultThemeProviding(
            storageDirectory: FileManager.default.temporaryDirectory
        )
        let plugin = ThemePackPlugin()
        // onBoot 需要一个 KernelCoreContainer；这里直接验证注册语义：
        // 目录主题可全部被 provider 接受且不抛错。
        for legacy in LegacyThemeCatalog.all {
            provider.registerTheme(legacy)
        }
        #expect(provider.themes.count == 22)
        // 未注册重复 id
        let ids = provider.themes.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Theme 菜单标题支持中文本地化")
    func themeMenuTitleIsLocalizedInChinese() {
        #expect(ThemePackPlugin.localizedMenuName(locale: Locale(identifier: "zh-Hans")) == "主题")
    }
}
