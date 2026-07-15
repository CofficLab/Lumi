import Foundation
import LumiLocalizationKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case plugins
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: LumiLocalization.string("General", bundle: .module)
        case .appearance: LumiLocalization.string("Appearance", bundle: .module)
        case .plugins: LumiLocalization.string("Plugins", bundle: .module)
        case .about: LumiLocalization.string("About", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .plugins: "puzzlepiece.extension"
        case .about: "info.circle"
        }
    }
}
