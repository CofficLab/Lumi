import AgentToolKit
import Foundation

public enum PackageStringLocalization {
    public static func string(
        _ key: String,
        table: String,
        bundle: Bundle,
        language: LanguagePreference
    ) -> String {
        if let catalog = catalog(table: table, bundle: bundle),
           let value = catalog.localizedValue(for: key, language: language)
        {
            return value
        }

        return String(
            localized: String.LocalizationValue(key),
            table: table,
            bundle: bundle,
            locale: language.locale,
            comment: ""
        )
    }

    private static func catalog(table: String, bundle: Bundle) -> StringCatalog? {
        guard let url = bundle.url(forResource: table, withExtension: "xcstrings") else {
            return nil
        }

        let cacheKey = url.path
        catalogCacheLock.lock()
        if let cached = catalogCache[cacheKey] {
            catalogCacheLock.unlock()
            return cached
        }
        catalogCacheLock.unlock()

        guard
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(StringCatalog.self, from: data)
        else {
            return nil
        }

        catalogCacheLock.lock()
        catalogCache[cacheKey] = catalog
        catalogCacheLock.unlock()
        return catalog
    }

    private static let catalogCacheLock = NSLock()
    nonisolated(unsafe) private static var catalogCache: [String: StringCatalog] = [:]
}

private struct StringCatalog: Decodable {
    let sourceLanguage: String?
    let strings: [String: StringCatalogEntry]

    func localizedValue(for key: String, language: LanguagePreference) -> String? {
        guard let entry = strings[key] else {
            return nil
        }

        for identifier in language.stringCatalogLocaleIdentifiers {
            if let value = entry.localizations?[identifier]?.stringUnit.value, !value.isEmpty {
                return value
            }
        }

        if let sourceLanguage,
           let value = entry.localizations?[sourceLanguage]?.stringUnit.value,
           !value.isEmpty
        {
            return value
        }

        return nil
    }
}

private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]?
}

private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogStringUnit
}

private struct StringCatalogStringUnit: Decodable {
    let value: String
}

private extension LanguagePreference {
    var stringCatalogLocaleIdentifiers: [String] {
        switch self {
        case .chinese:
            return ["zh-Hans", "zh"]
        case .english:
            return ["en"]
        }
    }
}
