import Foundation
import LumiCoreKit
import SwiftUI

enum VideoConverterLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: args)
    }
}
