import Foundation
import KitLocalization
import SwiftUI

/// Runtime localization helper for ImageToPDFPlugin bundle.
///
/// Wraps `LumiLocalization` so call sites stay short and consistent across
/// views, view models, and services.
enum ImageToPDFLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table)
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: LumiLocalization.preferredLocale(), arguments: args)
    }
}