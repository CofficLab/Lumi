import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case localProvider
    case remoteProvider
    case plugins
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .appearance: "外观"
        case .localProvider: "本地供应商"
        case .remoteProvider: "云端供应商"
        case .plugins: "插件"
        case .about: "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .localProvider: "cpu"
        case .remoteProvider: "network"
        case .plugins: "puzzlepiece.extension"
        case .about: "info.circle"
        }
    }
}
