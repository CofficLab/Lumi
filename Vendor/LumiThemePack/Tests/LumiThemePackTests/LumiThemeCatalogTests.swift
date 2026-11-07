import Foundation
import ProviderTheme
import Testing
@testable import LumiThemePack

/// 主题目录的数据契约：id 稳定性、排序、字段完整性、hex 合法性。
@Suite("主题目录")
struct LumiThemeCatalogTests {

    // MARK: - 目录规模与 id

    @Test("目录包含 19 个主题")
    func catalogHasExpectedCount() {
        #expect(LumiThemeCatalog.all.count == LumiThemeContract.catalogThemeCount)
        #expect(LumiThemeContract.catalogThemeCount == 19)
    }

    @Test("主题 id 唯一且顺序稳定")
    func catalogIDsAreUniqueAndStable() {
        let ids = LumiThemeCatalog.all.map(\.id)

        #expect(Set(ids).count == ids.count, "id 必须唯一")
        #expect(ids == [
            "lumi", "midnight", "sky", "aurora", "nebula", "void",
            "spring", "summer", "autumn", "winter", "github", "orchard",
            "mountain", "vscode-auto", "vscode-dark", "vscode-light",
            "river", "one-dark", "dracula",
        ])
    }

    @Test("sortOrder 严格递增，与目录顺序一致")
    func sortOrderIsAscending() {
        let orders = LumiThemeCatalog.all.map(\.sortOrder)

        #expect(zip(orders, orders.dropFirst()).allSatisfy { $0 < $1 },
                "sortOrder 应严格递增，保证列表顺序确定")
    }

    @Test("静态成员与目录内容一一对应")
    func staticMembersMatchCatalog() {
        let catalogIDs = Set(LumiThemeCatalog.all.map(\.id))
        let memberIDs: Set<String> = [
            LumiThemeCatalog.lumi.id, LumiThemeCatalog.midnight.id, LumiThemeCatalog.sky.id,
            LumiThemeCatalog.aurora.id, LumiThemeCatalog.nebula.id, LumiThemeCatalog.void.id,
            LumiThemeCatalog.spring.id, LumiThemeCatalog.summer.id, LumiThemeCatalog.autumn.id,
            LumiThemeCatalog.winter.id, LumiThemeCatalog.github.id, LumiThemeCatalog.orchard.id,
            LumiThemeCatalog.mountain.id, LumiThemeCatalog.vscodeAuto.id,
            LumiThemeCatalog.vscodeDark.id, LumiThemeCatalog.vscodeLight.id,
            LumiThemeCatalog.river.id, LumiThemeCatalog.oneDark.id, LumiThemeCatalog.dracula.id,
        ]

        #expect(memberIDs == catalogIDs)
    }

    // MARK: - 字段完整性

    @Test("每个主题的展示字段非空")
    func displayFieldsAreNotEmpty() {
        for theme in LumiThemeCatalog.all {
            #expect(!theme.displayName.isEmpty, "\(theme.id) 缺少 displayName")
            #expect(!theme.compactName.isEmpty, "\(theme.id) 缺少 compactName")
            #expect(!theme.description.isEmpty, "\(theme.id) 缺少 description")
            #expect(!theme.iconName.isEmpty, "\(theme.id) 缺少 iconName")
        }
    }

    @Test("compactName 长度不超过 displayName，适合窄菜单")
    func compactNameIsCompact() {
        for theme in LumiThemeCatalog.all {
            #expect(theme.compactName.count <= theme.displayName.count,
                    "\(theme.id) 的 compactName 比 displayName 还长")
        }
    }

    @Test("暗色主题的图标颜色在暗色外观下有定义")
    func darkThemesHaveDarkIconColor() {
        for theme in LumiThemeCatalog.all where theme.appearanceKind == .dark {
            #expect(!theme.iconColor.dark.isEmpty, "\(theme.id) 缺少暗色图标色")
        }
    }

    // MARK: - 色值合法性

    @Test("所有色值均为合法的 6 位 hex")
    func allHexValuesAreValid() {
        let invalidHexes = LumiThemeCatalog.all.flatMap { theme -> [String] in
            let pairs: [(String, ThemeHexPair)] = [
                ("iconColor", theme.iconColor),
                ("accentPrimary", theme.palette.accentPrimary),
                ("accentSecondary", theme.palette.accentSecondary),
                ("accentTertiary", theme.palette.accentTertiary),
                ("backgroundDeep", theme.palette.backgroundDeep),
                ("backgroundMedium", theme.palette.backgroundMedium),
                ("backgroundLight", theme.palette.backgroundLight),
                ("textPrimary", theme.palette.textPrimary),
                ("textSecondary", theme.palette.textSecondary),
                ("textTertiary", theme.palette.textTertiary),
            ]
            return pairs.flatMap { name, pair in
                [pair.light, pair.dark].compactMap { hex in
                    Self.isValidHex(hex) ? nil : "\(theme.id).\(name): \(hex)"
                }
            }
        }

        #expect(invalidHexes.isEmpty, "非法 hex：\(invalidHexes)")
    }

    @Test("双档色值的暗色主题，其暗色背景暗于亮色背景")
    func dualValueDarkThemesHaveDarkerDarkBackground() {
        let dualValueDarkThemes = LumiThemeCatalog.all.filter {
            $0.appearanceKind == .dark && $0.palette.backgroundDeep.light != $0.palette.backgroundDeep.dark
        }

        #expect(!dualValueDarkThemes.isEmpty)
        for theme in dualValueDarkThemes {
            let darkSide = Self.luminance(theme.palette.backgroundDeep.dark)
            let lightSide = Self.luminance(theme.palette.backgroundDeep.light)
            #expect(darkSide < lightSide, "\(theme.id) 的暗色档应暗于亮色档")
        }
    }

    @Test("所有主题的暗色档都不亮于其亮色档")
    func noThemeIsBrighterInDarkMode() {
        for theme in LumiThemeCatalog.all {
            let darkSide = Self.luminance(theme.palette.backgroundDeep.dark)
            let lightSide = Self.luminance(theme.palette.backgroundDeep.light)
            #expect(darkSide <= lightSide, "\(theme.id) 的暗色档不应亮于亮色档")
        }
    }

    @Test("暗色主题的暗色主文本亮于其暗色背景")
    func darkThemesHaveReadableDarkText() {
        for theme in LumiThemeCatalog.all where theme.appearanceKind == .dark {
            let background = Self.luminance(theme.palette.backgroundDeep.dark)
            let text = Self.luminance(theme.palette.textPrimary.dark)
            #expect(text > background,
                    "\(theme.id) 暗色下主文本与背景对比不足")
        }
    }

    // MARK: - 外观类型

    @Test("VS Code 三主题的外观类型分别为 system / dark / light")
    func vscodeVariantsHaveDistinctAppearance() {
        #expect(LumiThemeCatalog.vscodeAuto.appearanceKind == .system)
        #expect(LumiThemeCatalog.vscodeDark.appearanceKind == .dark)
        #expect(LumiThemeCatalog.vscodeLight.appearanceKind == .light)
    }

    @Test("仅 vscode-light 声明为固定亮色")
    func onlyVscodeLightIsLightAppearance() {
        let lightThemes = LumiThemeCatalog.all.filter { $0.appearanceKind == .light }

        #expect(lightThemes.map(\.id) == ["vscode-light"])
    }

    @Test("使用亮暗同值色板的是三个固定外观主题")
    func fixedAppearanceThemesUseSingleHexPairs() {
        // vscode-dark / vscode-light / one-dark / dracula 使用 ThemeHexPair(hex:)，
        // 亮暗同值；其余主题保留双档色值以便预览时切换。
        let singleHexThemes = LumiThemeCatalog.all.filter {
            $0.palette.backgroundDeep.light == $0.palette.backgroundDeep.dark
        }

        #expect(Set(singleHexThemes.map(\.id)) == ["vscode-dark", "vscode-light", "one-dark", "dracula"])
    }

    @Test("使用同值色板的主题均为固定外观（无 system）")
    func singleHexThemesHaveFixedAppearance() {
        for theme in LumiThemeCatalog.all
        where theme.palette.backgroundDeep.light == theme.palette.backgroundDeep.dark {
            #expect(theme.appearanceKind != .system,
                    "\(theme.id) 亮暗同值却声明为跟随系统，前景将无变化")
        }
    }

    // MARK: - Helpers

    private static func isValidHex(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy { $0.isHexDigit }
    }

    private static func luminance(_ hex: String) -> Double {
        guard hex.count == 6 else { return 0 }
        let value = UInt32(hex, radix: 16) ?? 0
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
