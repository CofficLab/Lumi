import Foundation
import LumiLocalizationKit

/// Runtime localization for this plugin bundle.
///
/// English strings are the localization keys and the default fallback.
enum OpenInCursorLocalization {
    static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: .module)
    }
}
