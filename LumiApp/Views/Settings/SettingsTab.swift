import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case plugins
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .appearance: "外观"
        case .plugins: "插件"
        case .about: "关于"
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
