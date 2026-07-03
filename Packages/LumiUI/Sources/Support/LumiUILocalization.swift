import Foundation

/// LumUI 内部使用的本地化工具
///
/// `String(localized:bundle:)` 在某些 Swift Package 中可能无法正确读取编译后的 `.lproj` 资源。
/// 此工具类提供可靠的本地化字符串查找，支持 `.lproj` 文件和 `.xcstrings` 回退机制。
///
/// ## 查找顺序
///
/// 1. 根据当前 Locale 确定候选语言列表
/// 2. 优先查找 `.lproj/<language>.lproj/Localizable.strings`
/// 3. 回退到 `.xcstrings` 目录结构
/// 4. 未找到则返回 key 本身
public enum LumiUILocalization {
    private static let missingMarker = "\u{FFFF}"
    private static let supportedLanguages = ["en", "zh-Hans", "zh-HK", "zh-TW", "zh-Hant"]
    nonisolated(unsafe) private static var catalogCaches: [CatalogCacheKey: [String: [String: String]]] = [:]

    public static func string(
        _ key: String,
        bundle: Bundle? = nil,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        let resolvedBundle = bundle ?? Bundle.module
        let catalog = catalog(for: resolvedBundle, table: table)

        for languageID in languageCandidates(for: locale) {
            if let value = localizedStringFromLproj(key, language: languageID, bundle: resolvedBundle, table: table) {
                return value
            }
            if let value = catalog[languageID]?[key] {
                return value
            }
        }

        return key
    }

    private static func localizedStringFromLproj(
        _ key: String,
        language: String,
        bundle: Bundle,
        table: String
    ) -> String? {
        guard let lprojPath = bundle.path(forResource: language, ofType: "lproj"),
              let languageBundle = Bundle(path: lprojPath) else {
            return nil
        }

        let value = languageBundle.localizedString(forKey: key, value: missingMarker, table: table)
        guard value != missingMarker else { return nil }
        return value
    }

    private static func catalog(for bundle: Bundle, table: String) -> [String: [String: String]] {
        let cacheKey = CatalogCacheKey(bundlePath: bundle.bundlePath, table: table)
        if let cached = catalogCaches[cacheKey] {
            return cached
        }

        let loaded = loadCatalog(bundle: bundle, table: table)
        catalogCaches[cacheKey] = loaded
        return loaded
    }

    private static func loadCatalog(bundle: Bundle, table: String) -> [String: [String: String]] {
        let catalogURLs = [
            bundle.url(forResource: table, withExtension: "xcstrings"),
            bundle.url(forResource: table, withExtension: "xcstrings", subdirectory: "Resources"),
        ].compactMap { $0 }

        guard let catalogURL = catalogURLs.first,
              let data = try? Data(contentsOf: catalogURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else {
            return [:]
        }

        var tables: [String: [String: String]] = [:]
        for language in supportedLanguages {
            tables[language] = [:]
        }

        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else {
                continue
            }

            for language in supportedLanguages {
                guard let localization = localizations[language] as? [String: Any],
                      let unit = localization["stringUnit"] as? [String: Any],
                      let text = unit["value"] as? String else {
                    continue
                }
                tables[language, default: [:]][key] = text
            }
        }

        return tables
    }

    private static func languageCandidates(for locale: Locale) -> [String] {
        var candidates: [String] = []

        func append(_ raw: String?) {
            guard let raw, !raw.isEmpty else { return }
            let normalized = normalizeLanguageID(raw)
            guard !candidates.contains(normalized) else { return }
            candidates.append(normalized)
        }

        for preferred in Locale.preferredLanguages {
            append(preferred)
        }
        append(locale.identifier)
        append("en")
        return candidates
    }

    private static func normalizeLanguageID(_ raw: String) -> String {
        let id = raw.replacingOccurrences(of: "_", with: "-")

        if id.hasPrefix("zh-Hans") || id.hasPrefix("zh-CN") {
            return "zh-Hans"
        }
        if id.hasPrefix("zh-HK") {
            return "zh-HK"
        }
        if id.hasPrefix("zh-TW") {
            return "zh-TW"
        }
        if id.hasPrefix("zh-Hant") || id.hasPrefix("zh-MO") {
            return "zh-Hant"
        }
        if id == "zh" {
            return "zh-Hans"
        }
        if id.hasPrefix("en") {
            return "en"
        }

        return id
    }
}

private struct CatalogCacheKey: Hashable {
    let bundlePath: String
    let table: String
}
