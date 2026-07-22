import Foundation
import HttpKit
import LumiKernel

/// Runtime localization for LLMKit / host-app bundle.
///
/// The provider-support localization strings originally lived in the
/// standalone `LumiLLMProviderSupport` package. After merging into
/// LumiKernel, then into LLMKit, they resolve through the main bundle
/// (no per-target resource bundle is emitted because the target ships
/// no `.xcstrings`). The host app supplies the actual strings.
public enum LumiLLMProviderSupportLocalization {
    static func string(_ key: String, locale: Locale = .current) -> String {
        let bundle = Bundle.allBundles.first(where: { $0.bundleIdentifier?.contains("LLMKit") ?? false })
            ?? Bundle.allBundles.first(where: { $0.bundleIdentifier?.contains("LumiKernel") ?? false })
            ?? Bundle.main
        return NSLocalizedString(key, bundle: bundle, comment: "")
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
