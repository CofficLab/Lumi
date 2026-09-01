import Foundation
import KitLocalization

/// Runtime localization for this plugin bundle.
///
/// English strings are the localization keys and the default fallback.
enum OpenInVSCodeLocalization {
    static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: .module)
    }
}
