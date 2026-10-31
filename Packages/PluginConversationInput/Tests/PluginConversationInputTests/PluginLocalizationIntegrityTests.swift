import Foundation
import Testing
@testable import PluginConversationInput

/// 本地化资源的完整性约束。
///
/// 这些断言不检查「文案翻译得好不好」，只检查**契约层面的硬性条件**——
/// 缺失的条目会在运行时退化成 key 本身或英文原文，属于「用户可见的缺陷」，
/// 却没有任何其他测试能发现：
///
/// - 单测无法渲染 SwiftUI 文案，只能断言状态布尔值；
/// - UI 测试按 identifier 定位控件，不读文案（见 `SendActionBarAccessibility`
///   的注释），因此文案缺失对 UI 测试完全不可见。
///
/// 所以这一层必须由「读 xcstrings 本身」的测试兜住。
@MainActor
@Suite("本地化资源完整性")
struct PluginLocalizationIntegrityTests {
    /// 项目规范要求插件统一提供的 4 种语言。
    ///
    /// - Note: `zh-Hant` 曾出现在本包 xcstrings 中，但它不在规范列表内。
    ///   这里断言的是「规范要求的语言必须齐全」，不反过来禁止额外语言，
    ///   以免把合法的补充翻译判为缺陷。
    private static let requiredLanguages = ["en", "zh-Hans", "zh-HK", "zh-TW"]

    // MARK: - 已使用但未本地化的文案

    @Test("Remove image / Remove file 等已上屏文案都有 4 种语言翻译")
    func accessibilityLabelsAreFullyLocalized() throws {
        // 这些文案直接出现在界面（AX label 与可见文本），
        // 任何一种语言缺失都会让对应用户读到英文或 key。
        let userFacingKeys = [
            "Remove image",
            "Remove file",
            "Binary file",
            "Text file",
            "Missing provider(s): %@",
        ]

        let catalog = try Self.loadCatalog()
        for key in userFacingKeys {
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

    @Test("Provider 错误文案含 en 翻译，不会在英文界面退化成 key")
    func providerErrorKeysIncludeEnglish() throws {
        // 缺陷现象：条目只有 zh-* 而缺 en，英文界面下 `String(localized:)`
        // 取不到值，直接把 key 当文案显示给用户。
        let keys = [
            "Provider Error",
            "Provider configuration error — click for details",
        ]

        let catalog = try Self.loadCatalog()
        for key in keys {
            let entry = try #require(
                catalog[key],
                "「\(key)」未出现在 xcstrings 中，但代码里已作为可见文案使用"
            )
            #expect(
                entry.localizations["en"] != nil,
                "「\(key)」缺少 en 翻译，英文界面会把 key 直接显示出来"
            )
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
        // 占位符数量不一致会让运行期 `String(localized:arguments:)` 崩溃或丢值。
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

    // MARK: - Helpers

    private struct CatalogEntry {
        /// 语言代码 → 译文。
        var localizations: [String: String]
    }

    private static func loadCatalog() throws -> [String: CatalogEntry] {
        let url = try #require(
            PluginLocalizationIntegrityTests.catalogURL(),
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
        // Tests/PluginConversationInputTests/<file> → 包根
        for _ in 0..<3 {
            directory.deleteLastPathComponent()
        }
        let url = directory
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
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
