import Foundation
import SwiftUI

/// 设置标签枚举
enum SettingTab: String, CaseIterable, Hashable {
    case general = "通用"
    case editor = "编辑器"
    case keyboardShortcuts = "快捷键"
    case theme = "主题"
    case localProvider = "本地供应商"
    case remoteProvider = "云端供应商"
    case plugins = "插件管理"
    case about = "关于"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .editor: return "chevron.left.forwardslash.chevron.right"
        case .keyboardShortcuts: return "keyboard"
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
        case .editor:
            EditorSettingsView()
        case .keyboardShortcuts:
            KeyboardShortcutsSettingsView()
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

// MARK: - SettingsSelection

/// 设置选择枚举，用于侧边栏导航状态管理
enum SettingsSelection: Hashable {
    case core(SettingTab)
    case plugin(String)
}
