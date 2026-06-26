import Foundation
import HttpKit
import LumiCoreKit

public enum LumiLLMProviderSupportLocalization {
    static func string(_ key: String, locale: Locale = .current) -> String {
        LumiPluginLocalization.string(key, bundle: .module, locale: locale)
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
