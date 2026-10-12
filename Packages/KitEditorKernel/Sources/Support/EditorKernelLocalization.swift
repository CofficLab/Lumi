import Foundation
import LumiLocalizationKit

/// Runtime localization for EditorKernel bundle.
///
/// Provides localization lookup scoped to EditorKernel by delegating to
/// `LumiLocalizationKit`. New code should prefer `LumiLocalization.string(...)`
/// directly; this wrapper exists for backward compatibility with existing
/// EditorKernel call sites.
public enum EditorKernelLocalization {
    public static func string(
        _ key: String,
        bundle: Bundle,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
    }
}
