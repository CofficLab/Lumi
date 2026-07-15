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
        case .general: String(localized: "General", bundle: .module)
        case .appearance: String(localized: "Appearance", bundle: .module)
        case .plugins: String(localized: "Plugins", bundle: .module)
        case .about: String(localized: "About", bundle: .module)
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
