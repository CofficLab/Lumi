import Foundation
import LumiLocalizationKit

enum LumiPluginLocalization {
    static func string(_ key: String, bundle: Bundle) -> String {
        LumiLocalization.string(key, bundle: bundle)
    }
}
