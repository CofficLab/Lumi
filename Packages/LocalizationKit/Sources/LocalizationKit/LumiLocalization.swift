import Foundation

/// Runtime localization for Swift Package Manager plugin bundles.
///
/// Swift 标准的 `String(localized:bundle: .module)` 在 SPM plugin bundle 中
/// 无法正确读取编译后的 `.lproj` 资源。该工具统一提供运行时本地化查找，
/// 并回退到 `.xcstrings` catalog，作为 Lumi 多语言基础设施。
public enum LumiLocalization {
    private static let missingMarker = "\u{FFFF}"
    private static let supportedLanguages = ["en", "zh-Hans", "zh-HK", "zh-TW", "zh-Hant"]

    /// 根据当前系统语言偏好查找本地化字符串。
    ///
    /// 查找顺序：
    /// 1. `Bundle.lproj` 中的 `Localizable.strings` / 指定 table
    /// 2. 回退到同 bundle 下的 `Localizable.xcstrings` catalog
    /// 3. 均未命中时返回原始 key，保证 UI 不会空白
    public static func string(
        _ key: String,
        bundle: Bundle,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        let catalog = catalog(for: bundle, table: table)

        for languageID in languageCandidates(for: locale) {
            if let value = localizedStringFromLproj(key, language: languageID, bundle: bundle, table: table) {
                return value
            }
            if let value = catalog[languageID]?[key] {
                return value
            }
        }

        return key
    }

    // MARK: - Private Helpers

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

        let cache = CatalogCache.shared
        if let cached = cache.value(forKey: cacheKey) {
            return cached
        }

        let loaded = loadCatalog(bundle: bundle, table: table)
        cache.setValue(loaded, forKey: cacheKey)
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

    /// 与插件字符串解析一致的首选 locale。
    ///
    /// 优先使用系统 `Locale.preferredLanguages`，再 fallback 到当前 locale，
    /// 最后 fallback 到 `en`。
    public static func preferredLocale(_ locale: Locale = .current) -> Locale {
        Locale(identifier: languageCandidates(for: locale).first ?? locale.identifier)
    }
}

private struct CatalogCacheKey: Hashable {
    let bundlePath: String
    let table: String
}

private final class CatalogCache: @unchecked Sendable {
    static let shared = CatalogCache()

    private let lock = NSLock()
    private var storage: [CatalogCacheKey: [String: [String: String]]] = [:]

    func value(forKey key: CatalogCacheKey) -> [String: [String: String]]? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func setValue(_ value: [String: [String: String]], forKey key: CatalogCacheKey) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }
}
