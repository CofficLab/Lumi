import Foundation

/// Runtime localization for the Lumi plugin string catalog.
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
        let value = target.localizedString(forKey: key, value: nil, table: table)
        // If the value equals the key, the string wasn't found → return the key itself.
        return value == key ? key : value
    }
}
