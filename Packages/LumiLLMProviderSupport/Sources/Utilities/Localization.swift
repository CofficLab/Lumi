import Foundation
import HttpKit
import LumiLocalizationKit

/// Runtime localization for LumiLLMProviderSupport bundle.
///
/// Provides localization lookup scoped to LumiLLMProviderSupport by delegating
/// to `LumiLocalizationKit`. New code should prefer `LumiLocalization.string(...)`
/// directly; this wrapper exists for backward compatibility with existing
/// call sites.
public enum LumiLLMProviderSupportLocalization {
    static func string(_ key: String, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: .module, locale: locale)
    }

    static func format(_ key: String, locale: Locale = .current, _ arguments: CVarArg...) -> String {
        let template = string(key, locale: locale)
        return String(format: template, locale: locale, arguments: arguments)
    }

    public static func userFacingDescription(for error: Error, locale: Locale = .current) -> String {
        let detail = LumiLLMFailureDetailResolver.resolve(from: error, locale: locale)
        let summary = detail.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            return summary
        }
        return detail.transportDetails?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? string("Request failed", locale: locale)
    }
}

extension LumiLLMProviderSupportError {
    func localizedDescription(locale: Locale) -> String {
        LumiLLMFailureDetailResolver.resolve(from: self, locale: locale).summary
    }
}
