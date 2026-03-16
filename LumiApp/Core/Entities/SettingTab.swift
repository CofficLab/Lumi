import Foundation
import SwiftUI

/// 设置标签枚举
enum SettingTab: String, CaseIterable, Hashable {
    case general = "通用"
    case theme = "主题"
    case localProvider = "本地供应商"
    case remoteProvider = "云端供应商"
    case plugins = "插件管理"
    case about = "关于"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .theme: return "paintbrush.fill"
        case .localProvider: return "cpu"
        case .remoteProvider: return "network"
        case .plugins: return "puzzlepiece.extension"
        case .about: return "info.circle"
        }
    }

    /// 对应的设置视图
    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .general:
            GeneralSettingView()
        case .theme:
            ThemeSettingView()
        case .localProvider:
            LocalProviderSettingsView()
        case .remoteProvider:
            RemoteProviderSettingsView()
        case .plugins:
            PluginSettingsView()
        case .about:
            AboutView()
        }
    }
}

