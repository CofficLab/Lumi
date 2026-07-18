import Foundation
import LocalizationKit
import SwiftUI

enum VideoConverterLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table)
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: LumiLocalization.preferredLocale(), arguments: args)
    }
}
