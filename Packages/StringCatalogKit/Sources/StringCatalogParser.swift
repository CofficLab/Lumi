import Foundation

public enum StringCatalogParser {
    public static func parse(_ source: String, locale: Locale = .current) throws -> StringCatalog {
        try parse(Data(source.utf8), locale: locale)
    }

    public static func parse(_ data: Data, locale: Locale = .current) throws -> StringCatalog {
        let decoded = try JSONDecoder().decode(RawCatalog.self, from: data)
        let entries = decoded.strings
            .map { key, entry in
                StringCatalog.Entry(
                    id: key,
                    key: key,
                    extractionState: entry.extractionState,
                    valuesByLanguage: entry.valuesByLanguage
                )
            }
            .sorted { lhs, rhs in
                lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
            }

        let languageIDs = languageIDs(from: decoded, sourceLanguage: decoded.sourceLanguage, locale: locale)
        let languages = languageIDs.map { languageID in
            let translatedCount = entries.reduce(0) { count, entry in
                guard let text = entry.valuesByLanguage[languageID]?.text,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return count
                }
                return count + 1
            }

            return StringCatalog.Language(
                id: languageID,
                displayName: displayName(for: languageID, locale: locale),
                completion: entries.isEmpty ? 0 : Double(translatedCount) / Double(entries.count),
                translatedCount: translatedCount,
                totalCount: entries.count,
                isSourceLanguage: languageID == decoded.sourceLanguage
            )
        }

        return StringCatalog(
            sourceLanguage: decoded.sourceLanguage,
            languages: languages,
            entries: entries
        )
    }

    private static func languageIDs(from catalog: RawCatalog, sourceLanguage: String, locale: Locale) -> [String] {
        let localizedIDs = catalog.strings.values.flatMap { $0.localizations.map { Array($0.keys) } ?? [] }
        return Set(localizedIDs)
            .union([sourceLanguage])
            .sorted { lhs, rhs in
                if lhs == sourceLanguage { return true }
                if rhs == sourceLanguage { return false }
                return displayName(for: lhs, locale: locale)
                    .localizedStandardCompare(displayName(for: rhs, locale: locale)) == .orderedAscending
            }
    }

    private static func displayName(for languageID: String, locale: Locale) -> String {
        locale.localizedString(forIdentifier: languageID)
            ?? Locale(identifier: "en").localizedString(forIdentifier: languageID)
            ?? languageID
    }
}

private struct RawCatalog: Decodable {
    let sourceLanguage: String
    let strings: [String: RawStringEntry]
}

private struct RawStringEntry: Decodable {
    let extractionState: String?
    let localizations: [String: RawLocalization]?

    var valuesByLanguage: [String: StringCatalog.Entry.Value] {
        localizations?.mapValues {
            StringCatalog.Entry.Value(
                text: $0.stringUnit?.value ?? $0.firstVariationValue,
                state: $0.stringUnit?.state ?? $0.firstVariationState
            )
        } ?? [:]
    }
}

private struct RawLocalization: Decodable {
    let stringUnit: RawStringUnit?
    let variations: [String: RawVariation]?

    var firstVariationValue: String? {
        firstStringUnit(in: variations)?.value
    }

    var firstVariationState: String? {
        firstStringUnit(in: variations)?.state
    }

    private func firstStringUnit(in variations: [String: RawVariation]?) -> RawStringUnit? {
        guard let variations else { return nil }
        for key in variations.keys.sorted() {
            guard let variation = variations[key] else { continue }
            if let stringUnit = variation.stringUnit {
                return stringUnit
            }
            if let nested = firstStringUnit(in: variation.variations) {
                return nested
            }
        }
        return nil
    }
}

private struct RawVariation: Decodable {
    let stringUnit: RawStringUnit?
    let variations: [String: RawVariation]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        stringUnit = try container.decodeIfPresent(RawStringUnit.self, forKey: DynamicCodingKey("stringUnit"))

        var nested: [String: RawVariation] = [:]
        for key in container.allKeys where key.stringValue != "stringUnit" {
            if let value = try? container.decode(RawVariation.self, forKey: key) {
                nested[key.stringValue] = value
            }
        }
        variations = nested.isEmpty ? nil : nested
    }
}

private struct RawStringUnit: Decodable {
    let state: String?
    let value: String?
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
