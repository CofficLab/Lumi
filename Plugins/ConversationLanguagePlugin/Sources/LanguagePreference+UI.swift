import AgentToolKit
import SwiftUI

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
            return String(localized: "Chinese Description", bundle: .module)
        case .english:
            return String(localized: "English Description", bundle: .module)
        }
    }
}
