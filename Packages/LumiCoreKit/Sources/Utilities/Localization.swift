import Foundation
import HttpKit
import LLMKit
import LumiLocalizationKit

/// Runtime localization for LLM provider support.
///
/// Provides localization lookup scoped to LLMKit/LumiCoreKit by delegating
/// to `LumiLocalizationKit`. New code should prefer `LumiLocalization.string(...)`
/// directly; this wrapper exists for backward compatibility with existing
/// call sites.
public enum LLMProviderSupportLocalization {
    public static func string(_ key: String, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: .module, locale: locale)
    }

    public static func format(_ key: String, locale: Locale = .current, _ arguments: CVarArg...) -> String {
        let template = string(key, locale: locale)
        return String(format: template, locale: locale, arguments: arguments)
    }

    public static func userFacingDescription(for error: Error, locale: Locale = .current) -> String {
        let detail = LLMFailureDetailResolver.resolve(from: error, locale: locale)
        let summary = detail.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            return summary
        }
        return detail.transportDetails?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? string("Request failed", locale: locale)
    }
}
