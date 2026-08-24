import Foundation
import LocalizationKit

/// Runtime localization for the Lumi plugin string catalog.
///
/// Delegates to `LumiLocalization` from LocalizationKit, which correctly
/// resolves `.xcstrings` catalogs in SPM plugin bundles (unlike the
/// standard `Bundle.localizedString(forKey:value:table:)` API).
///
/// The xcstrings resource lives in `LLMProviderManagerPlugin` and is shared
/// across all Lumi plugins that need localized strings. Pass an explicit
/// `bundle:` to override; otherwise the LLM provider manager's resource
/// bundle is used.
public enum LumiPluginLocalization {
    /// The shared resource bundle (LLM provider manager module).
    public static let resourceBundle: Bundle = .module

    public static func string(
        _ key: String,
        bundle: Bundle? = nil,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        let target = bundle ?? resourceBundle
        return LumiLocalization.string(key, bundle: target, table: table, locale: locale)
    }
}
