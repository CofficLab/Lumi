import Foundation
import LocalizationKit

/// Runtime localization for EditorTextView bundle.
///
/// Provides localization lookup scoped to EditorTextView by delegating to
/// `LocalizationKit`. New code should prefer `LumiLocalization.string(...)`
/// directly; this wrapper exists for backward compatibility with existing
/// EditorTextView call sites.
public enum EditorTextViewLocalization {
    public static func string(
        _ key: String,
        bundle: Bundle,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
    }
}
