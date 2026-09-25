import Foundation
import KitLocalization

enum BenchmarkLocalization {
    static func string(_ key: String, bundle: Bundle = .module, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
