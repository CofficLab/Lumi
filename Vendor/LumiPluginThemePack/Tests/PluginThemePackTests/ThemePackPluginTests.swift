import Foundation
import LumiThemePack
import ProviderTheme
import Testing

@testable import PluginThemePack

@MainActor
struct ThemePackPluginTests {

    /// 旧版主题目录包含 19 个主题（17 个插件，Vscode 插件含 3 个变体）。
    @Test
    func catalogHasAllLegacyThemes() {
        #expect(LumiThemeCatalog.all.count == 19)
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
        let actualIDs = Set(LumiThemeCatalog.all.map(\.id))
        #expect(actualIDs == expectedIDs)
        #expect(actualIDs.count == 19)
    }

    /// 每个主题的 id / 显示名 / 图标 / 外观类型齐全。
    @Test
    func catalogMetadataIsComplete() {
        for theme in LumiThemeCatalog.all {
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
        for legacy in LumiThemeCatalog.all {
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

    // MARK: - 可配置 id / order / policy

    /// 默认配置与 Lumi 原版一致。
    @Test("默认配置为 Lumi 标识与 required 策略")
    func defaultConfigurationMatchesLumi() {
        let plugin = ThemePackPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.theme-pack")
        #expect(plugin.order == 100)
        #expect(plugin.metadata.id == plugin.id)
        #expect(plugin.metadata.policy == .required)
        #expect(plugin.metadata.category == .design)
    }

    /// 宿主可传入自定义 id / order / policy（GitOK / Kuzee / Wakey / Netto 场景）。
    @Test("自定义 id、order、policy 透传到实例与元数据")
    func customConfigurationIsApplied() {
        let plugin = ThemePackPlugin(
            id: "com.example.custom.plugin.theme-pack",
            order: 79,
            policy: .enabledByDefault
        )
        #expect(plugin.id == "com.example.custom.plugin.theme-pack")
        #expect(plugin.order == 79)
        #expect(plugin.metadata.id == "com.example.custom.plugin.theme-pack")
        #expect(plugin.metadata.policy == .enabledByDefault)
    }

    /// 元数据名称与描述走本地化（英文源存在）。
    @Test("元数据文案已本地化")
    func metadataIsLocalized() {
        let plugin = ThemePackPlugin()
        #expect(!plugin.metadata.name.isEmpty)
        #expect(!plugin.metadata.description.isEmpty)
    }

    // MARK: - 可配置 themeIDs（只加载部分主题）

    /// 默认不传白名单时加载全部目录主题，行为与旧版一致。
    @Test("默认加载全部目录主题")
    func defaultThemeIDsLoadsFullCatalog() {
        let plugin = ThemePackPlugin()
        #expect(plugin.themeIDs == nil)
        #expect(plugin.themes.count == LumiThemeCatalog.all.count)
        #expect(plugin.themes.map(\.id) == LumiThemeCatalog.all.map(\.id))
    }

    /// 白名单透传到实例，并只保留命中的主题。
    @Test("themeIDs 白名单只保留命中的主题")
    func themeIDsFiltersThemes() {
        let plugin = ThemePackPlugin(themeIDs: ["dracula", "lumi"])

        #expect(plugin.themeIDs == ["dracula", "lumi"])
        #expect(plugin.themes.map(\.id) == ["lumi", "dracula"],
                "应按目录顺序返回，而非白名单书写顺序")
    }

    /// 白名单外的 id 被忽略，不影响其余主题生效。
    @Test("白名单中的未知 id 被忽略")
    func unknownThemeIDsAreIgnored() {
        let plugin = ThemePackPlugin(themeIDs: ["lumi", "not-a-real-theme"])

        #expect(plugin.themes.map(\.id) == ["lumi"])
    }

    /// 空白名单表示不加载任何目录主题。
    @Test("空白名单不加载目录主题")
    func emptyThemeIDsLoadsNoCatalogTheme() {
        let plugin = ThemePackPlugin(themeIDs: [])

        #expect(plugin.themes.isEmpty)
    }

    /// 元数据描述中的主题数量随实际生效集合变化，而非固定为目录总数。
    @Test("元数据描述随实际主题数量变化")
    func metadataDescriptionReflectsActualThemeCount() {
        let full = ThemePackPlugin()
        let subset = ThemePackPlugin(themeIDs: ["lumi", "dracula", "midnight"])

        #expect(full.metadata.description.contains("19"),
                "全量时应体现目录主题数")
        #expect(subset.metadata.description.contains("3"),
                "子集时应体现实际生效的主题数")
        #expect(!subset.metadata.description.contains("19"),
                "子集不应再出现目录总数")
    }

    /// 元数据描述的占位符已全部替换，不残留 %lld。
    @Test("元数据描述不残留格式占位符")
    func metadataDescriptionHasNoFormatPlaceholder() {
        for plugin in [ThemePackPlugin(), ThemePackPlugin(themeIDs: ["lumi"])] {
            #expect(!plugin.metadata.description.contains("%lld"),
                    "占位符未被替换：\(plugin.metadata.description)")
        }
    }

    /// 子集注册到 Provider 后，只有白名单内的目录主题被注册。
    @Test("按子集注册只注册白名单内的目录主题")
    func registerWithSubsetOnlyAddsWhitelistedThemes() {
        let provider = DefaultThemeProviding(
            storageDirectory: FileManager.default.temporaryDirectory
        )
        let builtinCount = provider.themes.count
        let plugin = ThemePackPlugin(themeIDs: ["lumi", "dracula"])

        LumiThemeRegistration.register(in: provider, themeIDs: plugin.themeIDs)

        // 内置 `lumi` 被目录同 id 主题覆盖，故仅 `dracula` 是净新增。
        #expect(provider.themes.count == builtinCount + 1)
        #expect(provider.themes.contains { $0.id == "dracula" })
        #expect(!provider.themes.contains { $0.id == "midnight" },
                "未列入白名单的目录主题不应注册")
    }

    /// 注销与注册对称：只撤回白名单内的主题。
    @Test("按子集注销只撤回白名单内的主题")
    func unregisterWithSubsetIsSymmetric() {
        let provider = DefaultThemeProviding(
            storageDirectory: FileManager.default.temporaryDirectory
        )
        let plugin = ThemePackPlugin(themeIDs: ["lumi", "dracula"])
        LumiThemeRegistration.register(in: provider, themeIDs: plugin.themeIDs)

        LumiThemeRegistration.unregister(from: provider, themeIDs: plugin.themeIDs)

        #expect(!provider.themes.contains { $0.id == "dracula" })
        #expect(!provider.themes.contains { $0.id == "lumi" })
    }

    /// 白名单可以借助 LumiThemeRegistration 校验出拼写错误的 id。
    @Test("可用 unknownIDs 校验白名单配置")
    func unknownIDsValidatesWhitelist() {
        #expect(LumiThemeRegistration.unknownIDs(in: ["lumi", "dracula"]).isEmpty)
        #expect(LumiThemeRegistration.unknownIDs(in: ["lumi", "typo"]) == ["typo"])
    }
}
