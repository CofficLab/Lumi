import AgentToolKit
import SwiftUI
import LumiCoreKit

extension LanguagePreference {
    var shortDisplayName: String {
        switch self {
        case .chinese: return "中"
        case .english: return "EN"
        }
    }

    var iconName: String {
        switch self {
        case .chinese: return "character.book.closed"
        case .english: return "textformat.abc"
        }
    }

    var descriptionText: String {
        switch self {
        case .chinese:
            return LumiPluginLocalization.string("Chinese Description", bundle: .module)
        case .english:
            return LumiPluginLocalization.string("English Description", bundle: .module)
        }
    }
}
