import XCTest

/// 本地化目录（`Resources/Localizable.xcstrings`）的完整性守卫。
///
/// 这些规则人工检查时都「看起来没问题」，却极易在后续改动中静默退化：
/// key 缺失会回退英文文案、占位符数量不一致会在运行时产出错乱文案或崩溃。
/// 把它们固化为测试，使「别人拿到的包一定本地化健全」成为可验证的事实，
/// 而不依赖作者的细心。
final class BookletLocalizationCatalogTests: XCTestCase {

    // MARK: - Fixtures

    /// 包内所有随包分发的语言。缺任意一个都视为目录不完整。
    private static let requiredLanguages = ["en", "zh-Hans", "zh-Hant", "zh-HK", "zh-TW"]

    /// 仓库根目录。由本文件路径上溯推导，避免依赖测试 bundle 的资源布局
    /// （目录挂在 `PluginBookletMaker` target 上，测试 target 看不到它）。
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)     // Tests/PluginBookletMakerTests/<this file>
            .deletingLastPathComponent()      // Tests/PluginBookletMakerTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // <repo root>
    }

    private static var catalogURL: URL {
        repositoryRoot.appendingPathComponent("Resources/Localizable.xcstrings")
    }

    /// 载入目录：`key -> (language -> 译文)`。
    private func loadCatalog(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: [String: String]] {
        let url = Self.catalogURL
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "\(url.lastPathComponent) 不是合法 JSON 对象",
            file: file,
            line: line
        )

        var result: [String: [String: String]] = [:]
        let strings = root["strings"] as? [String: Any] ?? [:]
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any]
            else { continue }
            var values: [String: String] = [:]
            for (language, payload) in localizations {
                guard let payload = payload as? [String: Any],
                      let unit = payload["stringUnit"] as? [String: Any],
                      let value = unit["value"] as? String
                else { continue }
                values[language] = value
            }
            result[key] = values
        }
        return result
    }

    /// 抽取 printf 风格占位符。
    ///
    /// 返回 (定位占位符的位置列表, 占位符总数)。CJK 语序与英文不同，翻译
    /// 使用 `%1$@` 这类定位占位符是**正确且必需**的，因此这里只校验
    /// 「数量」与「位置连续性」，不要求与英文顺序一致。
    private func placeholders(in format: String) -> (positional: [Int], total: Int) {
        let pattern = try! NSRegularExpression(pattern: "%(?:(\\d+)\\$)?([@a-zA-Z])")
        let range = NSRange(format.startIndex..., in: format)
        var positional: [Int] = []
        var plain = 0
        for match in pattern.matches(in: format, range: range) {
            if let posRange = Range(match.range(at: 1), in: format),
               !posRange.isEmpty,
               let position = Int(format[posRange]) {
                positional.append(position)
            } else {
                plain += 1
            }
        }
        return (positional, positional.count + plain)
    }

    /// 扫描 `Sources/` 下所有本地化调用点，收集被引用的 key。
    private func referencedKeys() throws -> [String: Set<String>] {
        let sources = Self.repositoryRoot.appendingPathComponent("Sources")
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        )

        // `BookletLocalization.string("…")` / `PDFSplitSegmentLocalization.string("…")`
        let pattern = try! NSRegularExpression(
            pattern: #"[A-Za-z]+Localization\.string\(\s*"([^"]*)""#
        )

        var keys: [String: Set<String>] = [:]
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            var buckets: [String: Set<String>] = [:]
            for match in pattern.matches(in: text, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
                buckets[file.lastPathComponent, default: []].insert(String(text[keyRange]))
            }
            for (file, set) in buckets {
                keys[file, default: []].formUnion(set)
            }
        }
        return keys
    }

    // MARK: - Tests

    /// 每个 key 在所有随包语言中都必须有非空译文。
    ///
    /// 缺失时 `LumiLocalization` 会原样回退英文，在中文界面里表现为
    /// 「个别文案漏翻译」——这类 bug 极难靠肉眼在全量文案中发现。
    func testEveryKeyIsTranslatedInAllLanguages() throws {
        let catalog = try loadCatalog()
        XCTAssertFalse(catalog.isEmpty, "本地化目录为空")

        var missing: [String] = []
        for (key, values) in catalog.sorted(by: { $0.key < $1.key }) {
            for language in Self.requiredLanguages {
                guard let value = values[language], !value.isEmpty else {
                    missing.append("\(key) → \(language)")
                    continue
                }
                // 占位符丢失也算缺失：译文非空也可能漏掉 %@。
                let source = self.placeholders(in: key)
                let translated = self.placeholders(in: value)
                if source.total != translated.total {
                    missing.append(
                        "\(key) → \(language)（占位符 \(translated.total) ≠ \(source.total)）"
                    )
                }
            }
        }
        XCTAssertTrue(
            missing.isEmpty,
            "以下 key 缺少完整译文：\n" + missing.joined(separator: "\n")
        )
    }

    /// 各语言的占位符数量必须与 key 一致，且定位占位符位置从 1 连续递增。
    ///
    /// 数量不一致会在 `String(format:)` 阶段产出错乱文案；位置不连续
    /// （如出现 `%3$@` 却无 `%1$`）属于非法格式串。
    func testFormatPlaceholdersStayConsistentAcrossLanguages() throws {
        let catalog = try loadCatalog()
        var problems: [String] = []

        for (key, values) in catalog.sorted(by: { $0.key < $1.key }) {
            let source = self.placeholders(in: key)
            guard source.total > 0 else { continue }

            for (language, value) in values.sorted(by: { $0.key < $1.key }) {
                let translated = self.placeholders(in: value)
                if translated.total != source.total {
                    problems.append(
                        "\(key) → \(language)：占位符数量 \(translated.total) ≠ \(source.total)"
                    )
                }
                if !translated.positional.isEmpty {
                    let sorted = translated.positional.sorted()
                    let expected = Array(1 ... sorted.count)
                    if sorted != expected {
                        problems.append(
                            "\(key) → \(language)：定位占位符 \(sorted) 不连续，应为 \(expected)"
                        )
                    }
                }
            }
        }
        XCTAssertTrue(
            problems.isEmpty,
            "占位符不一致：\n" + problems.joined(separator: "\n")
        )
    }

    /// 代码里引用的每个 key 都必须存在于目录中。
    ///
    /// 这是最容易在迭代中悄悄破掉的一条：新增文案时忘了写进 xcstrings，
    /// 编译照常通过、界面照常显示英文，只是没人注意到那句话没翻译。
    func testEveryReferencedKeyExistsInCatalog() throws {
        let catalog = try loadCatalog()
        let keys = Set(catalog.keys)
        let referenced = try referencedKeys()

        var missing: [String] = []
        for (file, fileKeys) in referenced.sorted(by: { $0.key < $1.key }) {
            for key in fileKeys.sorted() where !keys.contains(key) {
                missing.append("\(file)：\(key)")
            }
        }
        XCTAssertTrue(
            missing.isEmpty,
            "代码引用了目录中不存在的 key（会静默回退英文）：\n"
                + missing.joined(separator: "\n")
        )
    }

    /// 目录自身的元数据必须自洽：`sourceLanguage` 为 en、版本号为 1.0。
    ///
    /// 依赖「en」作为源语言；若目录里没有 en 条目，所有 key 都会退化为
    /// key 字面量本身（界面直接显示 "Output paper" 这类英文串）。
    func testCatalogDeclaresEnglishAsSourceLanguage() throws {
        let data = try Data(contentsOf: Self.catalogURL)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(root["sourceLanguage"] as? String, "en")
        XCTAssertEqual(root["version"] as? String, "1.0")
    }
}