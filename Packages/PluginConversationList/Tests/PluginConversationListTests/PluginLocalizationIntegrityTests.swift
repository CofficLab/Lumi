import Foundation
import Testing
@testable import PluginConversationList

/// 本地化资源的完整性约束（回归 #1299）。
///
/// 单测无法渲染 SwiftUI 文案，UI 测试按 identifier 定位控件不读文案，
/// 因此「硬编码中文字面量 / 目录缺条目」对这两层测试完全不可见；
/// 本套件直接读 xcstrings 与编译后的 .lproj 产物兜住契约。
@MainActor
@Suite("本地化资源完整性")
struct PluginLocalizationIntegrityTests {
    /// 项目规范要求插件统一提供的 4 种语言。
    private static let requiredLanguages = ["en", "zh-Hans", "zh-HK", "zh-TW"]

    /// #1299 的八处用户可见文案，外加同一菜单里已本地化的对照项。
    private static let userFacingKeys = [
        "Delete",
        "No conversations yet",
        "Failed to load conversations",
        "All projects",
        "View conversation statistics",
        "%lld conversations",
        "Project conversations (%@)",
        "Conversations from all projects",
        "Stop current conversation",
    ]

    /// #1299 八处文案约定的 zh-Hans 译文（en 原文即 key 本身）。
    private static let pinnedSimplifiedChinese: [String: String] = [
        "Delete": "删除",
        "No conversations yet": "暂无对话",
        "Failed to load conversations": "无法加载对话",
        "All projects": "所有项目",
        "View conversation statistics": "查看对话统计",
        "%lld conversations": "%lld 个对话",
        "Project conversations (%@)": "项目对话 (%@)",
        "Conversations from all projects": "所有项目的对话",
    ]

    @Test("#1299 的全部上屏文案都有 4 种规范语言翻译")
    func userFacingKeysAreFullyLocalized() throws {
        let catalog = try Self.loadCatalog()
        for key in Self.userFacingKeys {
            let entry = try #require(
                catalog[key],
                "「\(key)」未出现在 xcstrings 中，但代码里已作为可见文案使用"
            )
            let languages = Set(entry.localizations.keys)
            let missing = Self.requiredLanguages.filter { !languages.contains($0) }
            #expect(
                missing.isEmpty,
                "「\(key)」缺少语言翻译：\(missing.sorted().joined(separator: ", "))"
            )
        }
    }

    @Test("英文原文与简体中文译文与约定文案一致（回归 #1299）")
    func pinnedTranslationsMatchCatalog() throws {
        let catalog = try Self.loadCatalog()
        for (key, zhHans) in Self.pinnedSimplifiedChinese {
            let entry = try #require(catalog[key], "「\(key)」未进入本地化资源")
            #expect(entry.localizations["en"] == key, "「\(key)」缺 en 原文")
            #expect(entry.localizations["zh-Hans"] == zhHans, "「\(key)」zh-Hans 译文不符")
        }
    }

    @Test("所有已登记条目都含 4 种规范语言")
    func everyCatalogEntryCoversRequiredLanguages() throws {
        let catalog = try Self.loadCatalog()

        for (key, entry) in catalog.sorted(by: { $0.key < $1.key }) {
            let languages = Set(entry.localizations.keys)
            let missing = Self.requiredLanguages.filter { !languages.contains($0) }
            let detail = "条目「\(key)」缺少语言：\(missing.sorted().joined(separator: ", "))"
                + "；实际已有：\(languages.sorted().joined(separator: ", "))"
            #expect(missing.isEmpty, Comment(rawValue: detail))
        }
    }

    @Test("带占位符的文案四种语言占位符一致")
    func placeholdersAreConsistentAcrossLanguages() throws {
        // 占位符数量不一致会让运行期 String(format:) 丢值或崩溃。
        let catalog = try Self.loadCatalog()

        for (key, entry) in catalog.sorted(by: { $0.key < $1.key }) {
            guard let source = entry.localizations["en"] else {
                #expect(Bool(false), "条目「\(key)」缺 en，无法作为占位符基准")
                continue
            }
            let sourceCount = Self.placeholderCount(source)

            for language in Self.requiredLanguages where language != "en" {
                guard let translated = entry.localizations[language] else { continue }
                #expect(
                    Self.placeholderCount(translated) == sourceCount,
                    "条目「\(key)」在 \(language) 的占位符数量与 en 不一致"
                )
            }
        }
    }

    @Test("编译产物各语言都含 #1299 文案，不依赖机器语言")
    func compiledBundlesContainPinnedStrings() throws {
        // 直接读编译后的 .lproj 字符串表：与运行机器的 preferredLanguages 无关，
        // 条目没进编译产物时这里必然红。
        let english = try Self.compiledStrings(language: "en")
        let simplified = try Self.compiledStrings(language: "zh-Hans")
        for (key, zhHans) in Self.pinnedSimplifiedChinese {
            #expect(english[key] == key, "en.lproj 缺少「\(key)」或译文不符")
            #expect(simplified[key] == zhHans, "zh-Hans.lproj 缺少「\(key)」或译文不符")
        }
        let traditional = try Self.compiledStrings(language: "zh-Hant")
        #expect(traditional["All projects"] == "所有專案")
        #expect(traditional["Conversations from all projects"] == "所有專案的對話")
    }

    // MARK: - Helpers

    private struct CatalogEntry {
        /// 语言代码 → 译文。
        var localizations: [String: String]
    }

    private static func loadCatalog() throws -> [String: CatalogEntry] {
        let url = try #require(
            Self.catalogURL(),
            "找不到本包的 xcstrings 资源文件"
        )
        let data = try Data(contentsOf: url)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "xcstrings 根节点不是 JSON 对象"
        )
        let strings = try #require(root["strings"] as? [String: Any], "xcstrings 缺少 strings 节点")

        var result: [String: CatalogEntry] = [:]
        for (key, value) in strings {
            guard let value = value as? [String: Any] else {
                result[key] = CatalogEntry(localizations: [:])
                continue
            }
            let raw = (value["localizations"] as? [String: Any]) ?? [:]
            var localizations: [String: String] = [:]
            for (language, unit) in raw {
                guard let unit = unit as? [String: Any],
                      let stringUnit = unit["stringUnit"] as? [String: Any],
                      let text = stringUnit["value"] as? String else { continue }
                localizations[language] = text
            }
            result[key] = CatalogEntry(localizations: localizations)
        }
        return result
    }

    /// 从包目录定位 xcstrings（测试运行时的当前目录不可依赖）。
    private static func catalogURL() -> URL? {
        var directory = URL(fileURLWithPath: #filePath)
        // Tests/PluginConversationListTests/<file> → 包根
        for _ in 0..<3 {
            directory.deleteLastPathComponent()
        }
        let url = directory
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 读取编译后指定语言的 Localizable.strings。
    private static func compiledStrings(language: String) throws -> [String: String] {
        let bundle = pluginLocalization.bundle
        let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
    }

    /// 统计 `%@` / `%lld` / `%1$@` 这类占位符的出现次数。
    private static func placeholderCount(_ text: String) -> Int {
        var count = 0
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "%" {
                let next = text.index(after: index)
                guard next < text.endIndex else { break }
                if text[next] == "%" {
                    // 转义 %% 不算占位符。
                    index = text.index(after: next)
                    continue
                }
                count += 1
                index = next
                continue
            }
            index = text.index(after: index)
        }
        return count
    }
}