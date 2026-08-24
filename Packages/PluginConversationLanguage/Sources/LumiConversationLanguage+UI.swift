import KernelLumi
import SwiftUI

extension LumiConversationLanguage {
    var toolbarIconName: String {
        switch self {
        case .chinese:
            "character.book.closed"
        case .english:
            "textformat.abc"
        }
    }

    var shortCode: String {
        switch self {
        case .chinese:
            "中文"
        case .english:
            "EN"
        }
    }

    var displayName: String {
        switch self {
        case .chinese:
            LumiPluginLocalization.string("Chinese", bundle: .module)
        case .english:
            LumiPluginLocalization.string("English", bundle: .module)
        }
    }

    var descriptionText: String {
        switch self {
        case .chinese:
            LumiPluginLocalization.string("Chinese Description", bundle: .module)
        case .english:
            LumiPluginLocalization.string("English Description", bundle: .module)
        }
    }

    var helpText: String {
        switch self {
        case .chinese:
            LumiPluginLocalization.string("Current Chinese Help", bundle: .module)
        case .english:
            LumiPluginLocalization.string("Current English Help", bundle: .module)
        }
    }
}
