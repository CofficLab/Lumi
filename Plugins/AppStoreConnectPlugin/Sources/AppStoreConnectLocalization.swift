import Foundation
import LocalizationKit

/// Plugin-scoped localization helper for AppStoreConnectPlugin.
///
/// Defaults `bundle` to `.module` so the 270+ call-sites can use the short form.
enum AppStoreConnectLocalization {
    static func string(
        _ key: String,
        bundle: Bundle = .module,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
    }

    /// Variadic format-style overload: looks up the key, then applies `String(format:)`.
    static func string(
        _ key: String,
        _ args: CVarArg...,
        bundle: Bundle = .module,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        let template = LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
        return String(format: template, arguments: args)
    }
}
