import Foundation
import ProviderTheme
import Testing
@testable import LumiThemePack

/// `LumiThemeContract` 的计数与 id 集合契约，以及 `LumiThemeRegistration` 的注册/注销行为。
@Suite("主题注册契约")
@MainActor
struct LumiThemeRegistrationTests {

    // MARK: - 计数契约

    @Test("可选择主题数为目录主题数加三个内置外观")
    func selectableCountIsDerivedFromCatalog() {
        #expect(LumiThemeContract.selectableThemeCount == 22)
        #expect(LumiThemeContract.selectableThemeCount
                == LumiThemeContract.catalogThemeCount
                + LumiThemeContract.additionalBuiltinThemeIDs.count)
    }

    @Test("附加内置主题 id 稳定且与目录 id 不重叠")
    func additionalBuiltinIDsAreStableAndDisjoint() {
        #expect(LumiThemeContract.additionalBuiltinThemeIDs == ["lumi-system", "lumi-dark", "lumi-light"])

        let catalogIDs = Set(LumiThemeCatalog.all.map(\.id))
        let overlap = catalogIDs.intersection(LumiThemeContract.additionalBuiltinThemeIDs)
        #expect(overlap.isEmpty, "目录与内置主题 id 冲突：\(overlap)")
    }

    @Test("可选择 id 集合唯一")
    func selectableIDsAreUnique() {
        let ids = LumiThemeContract.selectableThemeIDs

        #expect(ids.count == LumiThemeContract.selectableThemeCount)
        #expect(Set(ids).count == ids.count)
    }

    // MARK: - 注册

    @Test("注册后 Provider 覆盖内置主题并达到约定数量")
    func registerReachesContractCount() {
        let provider = DefaultThemeProviding()
        let builtinCount = provider.themes.count

        LumiThemeRegistration.register(in: provider)

        #expect(builtinCount == 4, "Provider 默认注册 4 个内置主题")
        #expect(provider.themes.count == LumiThemeContract.selectableThemeCount)
    }

    @Test("注册后 id 集合等于契约定义")
    func registerProducesContractIDs() {
        let provider = DefaultThemeProviding()

        LumiThemeRegistration.register(in: provider)

        #expect(Set(provider.themes.map(\.id)) == Set(LumiThemeContract.selectableThemeIDs))
    }

    @Test("共享 lumi 主题覆盖内置 lumi 而非新增条目")
    func sharedLumiOverridesBuiltin() {
        let provider = DefaultThemeProviding()

        LumiThemeRegistration.register(in: provider)

        let lumis = provider.themes.filter { $0.id == "lumi" }
        #expect(lumis.count == 1)
        #expect(lumis.first?.palette == LumiThemeCatalog.lumi.palette,
                "共享目录应覆盖内置 lumi 的色板")
        #expect(lumis.first?.sortOrder == LumiThemeCatalog.lumi.sortOrder)
    }

    @Test("注册后主题按 sortOrder 升序排列")
    func registerKeepsSortOrder() {
        let provider = DefaultThemeProviding()

        LumiThemeRegistration.register(in: provider)

        let orders = provider.themes.map(\.sortOrder)
        #expect(zip(orders, orders.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test("目录 sortOrder 均大于内置 sortOrder，注册后内置主题排在前面")
    func builtinsSortBeforeSharedThemes() {
        let provider = DefaultThemeProviding()

        LumiThemeRegistration.register(in: provider)

        let catalogIDs = Set(LumiThemeCatalog.all.map(\.id))
        let lastBuiltinIndex = provider.themes.lastIndex {
            LumiThemeContract.additionalBuiltinThemeIDs.contains($0.id)
        }
        let firstCatalogIndex = provider.themes.firstIndex { catalogIDs.contains($0.id) }

        #expect(lastBuiltinIndex != nil)
        #expect(firstCatalogIndex != nil)
        if let lastBuiltinIndex, let firstCatalogIndex {
            #expect(lastBuiltinIndex < firstCatalogIndex,
                    "内置 sortOrder(100/200/300) 应小于目录(1000+)")
        }
    }

    @Test("重复注册幂等，不产生重复条目")
    func registerIsIdempotent() {
        let provider = DefaultThemeProviding()

        LumiThemeRegistration.register(in: provider)
        let firstCount = provider.themes.count
        LumiThemeRegistration.register(in: provider)

        #expect(provider.themes.count == firstCount)
        #expect(Set(provider.themes.map(\.id)).count == firstCount)
    }

    // MARK: - 注销

    @Test("注销后仅剩三个内置外观主题")
    func unregisterRemovesSharedThemes() {
        let provider = DefaultThemeProviding()
        LumiThemeRegistration.register(in: provider)

        LumiThemeRegistration.unregister(from: provider)

        // 目录的 `lumi` 覆盖了内置 `lumi`，注销后该 id 不再有来源，
        // 因此只剩三个附加内置主题。
        #expect(Set(provider.themes.map(\.id)) == Set(LumiThemeContract.additionalBuiltinThemeIDs))
        #expect(!provider.themes.contains { $0.id == "lumi" })
    }

    @Test("注销后内置三主题的色板保持不变")
    func unregisterKeepsBuiltinPalettes() {
        let provider = DefaultThemeProviding()
        LumiThemeRegistration.register(in: provider)
        let builtinPalettesBefore = Dictionary(
            uniqueKeysWithValues: provider.themes
                .filter { LumiThemeContract.additionalBuiltinThemeIDs.contains($0.id) }
                .map { ($0.id, $0.palette) }
        )

        LumiThemeRegistration.unregister(from: provider)

        for theme in provider.themes {
            #expect(theme.palette == builtinPalettesBefore[theme.id],
                    "\(theme.id) 的内置色板不应被目录污染")
        }
    }

    @Test("注销未注册的主题不影响现有列表")
    func unregisterIgnoresUnknownIDs() {
        let provider = DefaultThemeProviding()
        let baseline = provider.themes

        provider.unregisterTheme(id: "not-registered")

        #expect(provider.themes == baseline)
    }

    @Test("注销后再注册可恢复目录状态")
    func registerAfterUnregisterRestoresCatalog() {
        let provider = DefaultThemeProviding()
        LumiThemeRegistration.register(in: provider)
        LumiThemeRegistration.unregister(from: provider)

        LumiThemeRegistration.register(in: provider)

        #expect(provider.themes.count == LumiThemeContract.selectableThemeCount)
        #expect(Set(provider.themes.map(\.id)) == Set(LumiThemeContract.selectableThemeIDs))
    }

    // MARK: - 子集注册（themeIDs 白名单）

    /// 构造使用临时目录的 Provider，避免测试写本机 Application Support。
    private static func makeProvider() -> DefaultThemeProviding {
        DefaultThemeProviding(storageDirectory: FileManager.default.temporaryDirectory)
    }

    @Test("nil 白名单返回全量目录")
    func nilWhitelistReturnsFullCatalog() {
        let themes = LumiThemeRegistration.themes(for: nil)

        #expect(themes.count == LumiThemeContract.catalogThemeCount)
        #expect(themes.map(\.id) == LumiThemeCatalog.all.map(\.id))
    }

    @Test("子集只返回白名单命中的主题，且保持目录顺序")
    func subsetKeepsCatalogOrder() {
        let themes = LumiThemeRegistration.themes(for: ["dracula", "lumi", "midnight"])

        #expect(themes.map(\.id) == ["lumi", "midnight", "dracula"],
                "应按目录顺序返回，而非白名单书写顺序")
    }

    @Test("白名单外的 id 被忽略，不影响其余主题")
    func subsetIgnoresUnknownIDs() {
        let themes = LumiThemeRegistration.themes(for: ["lumi", "not-a-real-theme"])

        #expect(themes.map(\.id) == ["lumi"])
    }

    @Test("空白名单返回空集合")
    func emptyWhitelistReturnsEmpty() {
        #expect(LumiThemeRegistration.themes(for: []).isEmpty)
    }

    @Test("白名单重复 id 不产生重复主题")
    func duplicateIDsInWhitelistAreDeduplicated() {
        let themes = LumiThemeRegistration.themes(for: ["lumi", "lumi", "dracula"])

        #expect(themes.map(\.id) == ["lumi", "dracula"])
    }

    @Test("unknownIDs 报告白名单中不存在于目录的 id 并去重")
    func unknownIDsReportsTypos() {
        let unknown = LumiThemeRegistration.unknownIDs(in: ["lumi", "typo-a", "typo-b", "typo-a"])

        #expect(unknown == ["typo-a", "typo-b"])
        #expect(LumiThemeRegistration.unknownIDs(in: nil).isEmpty)
        #expect(LumiThemeRegistration.unknownIDs(in: ["lumi", "dracula"]).isEmpty)
    }

    @Test("按子集注册后，Provider 中只新增白名单主题")
    func registerSubsetOnlyAddsWhitelistedThemes() {
        let provider = Self.makeProvider()
        let builtinCount = provider.themes.count

        LumiThemeRegistration.register(in: provider, themeIDs: ["lumi", "dracula"])

        // 内置 `lumi` 被目录同 id 主题覆盖，故白名单只体现为 id 集合而非新增两条。
        let additionalBuiltin = Set(LumiThemeContract.additionalBuiltinThemeIDs)
        #expect(Set(provider.themes.map(\.id)) == additionalBuiltin.union(["lumi", "dracula"]))
        #expect(provider.themes.count == builtinCount + 1,
                "仅 `dracula` 是净新增，`lumi` 覆盖了内置同 id 条目")
        #expect(!provider.themes.contains { $0.id == "midnight" },
                "未列入白名单的目录主题不应注册")
    }

    @Test("按子集注销是对称的，只撤回白名单主题")
    func unregisterSubsetIsSymmetric() {
        let provider = Self.makeProvider()
        LumiThemeRegistration.register(in: provider, themeIDs: ["lumi", "dracula"])

        LumiThemeRegistration.unregister(from: provider, themeIDs: ["lumi", "dracula"])

        #expect(Set(provider.themes.map(\.id)) == Set(LumiThemeContract.additionalBuiltinThemeIDs))
    }

    @Test("注销子集不影响已注册的其他目录主题")
    func unregisterSubsetLeavesOtherThemes() {
        let provider = Self.makeProvider()
        LumiThemeRegistration.register(in: provider)
        let baseline = provider.themes

        LumiThemeRegistration.unregister(from: provider, themeIDs: ["dracula"])

        #expect(provider.themes != baseline)
        #expect(!provider.themes.contains { $0.id == "dracula" })
        #expect(provider.themes.contains { $0.id == "midnight" },
                "不在注销白名单中的主题应保留")
    }

    @Test("先全量注册再子集注册不产生重复条目")
    func registerSubsetAfterFullRegisterIsIdempotent() {
        let provider = Self.makeProvider()
        LumiThemeRegistration.register(in: provider)
        let fullCount = provider.themes.count

        LumiThemeRegistration.register(in: provider, themeIDs: ["lumi", "dracula"])

        #expect(provider.themes.count == fullCount)
        #expect(Set(provider.themes.map(\.id)).count == fullCount)
    }

    @Test("子集外的主题被注销后，选中态回退到白名单内的可用主题")
    func unregisterSelectedOutsideSubsetFallsBackIntoSubset() {
        let provider = Self.makeProvider()
        LumiThemeRegistration.register(in: provider)
        try? provider.selectTheme(id: "midnight")

        // 注销选中主题后 Provider 回退到剩余第一个，且选中态必须可解析。
        LumiThemeRegistration.unregister(from: provider, themeIDs: ["midnight"])

        #expect(provider.selectedTheme != nil, "选中主题被注销后不应出现空选中态")
        #expect(provider.selectedTheme?.id != "midnight")
    }
}
