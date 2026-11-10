import ProviderTheme
import Testing
@testable import LumiThemePack

/// `ThemeAppearanceFilter` 与 `ThemeFilter` 的外观筛选语义。
///
/// 外观页已移除主题搜索，`ThemeFilter` 只负责「按外观筛选」，
/// 因此这里不再覆盖关键字匹配。
@Suite("主题外观筛选")
@MainActor
struct ThemeFilterTests {

    // MARK: - 外观筛选匹配

    @Test("all 匹配所有外观类型")
    func allFilterMatchesEverything() {
        for kind in [ThemeAppearanceKind.dark, .light, .system] {
            #expect(ThemeAppearanceFilter.all.matches(kind))
        }
    }

    @Test("具体外观筛选只匹配自身")
    func specificFilterMatchesOnlySameKind() {
        #expect(ThemeAppearanceFilter.dark.matches(.dark))
        #expect(!ThemeAppearanceFilter.dark.matches(.light))
        #expect(!ThemeAppearanceFilter.dark.matches(.system))

        #expect(ThemeAppearanceFilter.light.matches(.light))
        #expect(!ThemeAppearanceFilter.light.matches(.dark))

        #expect(ThemeAppearanceFilter.system.matches(.system))
        #expect(!ThemeAppearanceFilter.system.matches(.dark))
    }

    @Test("筛选器覆盖四种模式且 id 为 rawValue")
    func filterCasesAreComplete() {
        #expect(ThemeAppearanceFilter.allCases.map(\.rawValue) == ["all", "dark", "light", "system"])
        #expect(ThemeAppearanceFilter.allCases.map(\.id) == ["all", "dark", "light", "system"])
    }

    @Test("各筛选器标题互不相同")
    func filterTitlesAreDistinct() {
        let titles = ThemeAppearanceFilter.allCases.map(\.title)
        #expect(Set(titles).count == titles.count)
        #expect(titles.allSatisfy { !$0.isEmpty })
    }

    // MARK: - 筛选结果

    @Test("all 返回全部主题并保持输入顺序")
    func allFilterReturnsEveryThemeInOrder() {
        let themes = [
            ThemeFixture.theme(id: "c", appearanceKind: .light),
            ThemeFixture.theme(id: "a", appearanceKind: .dark),
            ThemeFixture.theme(id: "b", appearanceKind: .system),
        ]

        let result = ThemeFilter.filter(themes: themes, filter: .all)

        #expect(result.map(\.id) == ["c", "a", "b"])
    }

    @Test("空主题列表返回空结果")
    func emptyThemesReturnEmpty() {
        let result = ThemeFilter.filter(themes: [], filter: .all)

        #expect(result.isEmpty)
    }

    @Test("外观筛选只保留对应外观类型的主题")
    func appearanceFilterKeepsMatchingKinds() {
        let themes = [
            ThemeFixture.theme(id: "d1", appearanceKind: .dark),
            ThemeFixture.theme(id: "d2", appearanceKind: .dark),
            ThemeFixture.theme(id: "l1", appearanceKind: .light),
            ThemeFixture.theme(id: "s1", appearanceKind: .system),
        ]

        #expect(ThemeFilter.filter(themes: themes, filter: .dark).map(\.id) == ["d1", "d2"])
        #expect(ThemeFilter.filter(themes: themes, filter: .light).map(\.id) == ["l1"])
        #expect(ThemeFilter.filter(themes: themes, filter: .system).map(\.id) == ["s1"])
        #expect(ThemeFilter.filter(themes: themes, filter: .all).count == 4)
    }

    @Test("筛选结果保持输入顺序")
    func resultsKeepInputOrder() {
        let themes = [
            ThemeFixture.theme(id: "z", appearanceKind: .dark),
            ThemeFixture.theme(id: "m", appearanceKind: .dark),
            ThemeFixture.theme(id: "a", appearanceKind: .dark),
        ]

        let result = ThemeFilter.filter(themes: themes, filter: .dark)

        #expect(result.map(\.id) == ["z", "m", "a"])
    }

    @Test("筛选真实目录时各外观均有命中")
    func filterRealCatalogByAppearance() {
        let themes = LumiThemeCatalog.all

        #expect(!ThemeFilter.filter(themes: themes, filter: .dark).isEmpty)
        #expect(!ThemeFilter.filter(themes: themes, filter: .light).isEmpty)
        #expect(!ThemeFilter.filter(themes: themes, filter: .system).isEmpty)
        #expect(ThemeFilter.filter(themes: themes, filter: .all).count == themes.count)
    }
}
