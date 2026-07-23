import Foundation
import LumiKernel
import LumiLocalizationKit

// MARK: - Built-in Settings Tabs

/// 宿主内置的设置标签。
///
/// 保留 enum rawValue 作为稳定 id,便于 i18n 改变时不破坏状态。
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

// MARK: - Unified Tab Selection (Built-in + Plugin)

/// 设置面板的统一 tab 选择器,把内置 enum 和插件
/// (`SettingsTabItem.id`) 合并成一份选择器。
enum SettingsTabID: Hashable {
    case builtin(SettingsTab)
    case plugin(String)
}

/// 侧边栏显示一个 tab 所需的扁平数据。宿主把内置 enum 和插件贡献的
/// `SettingsTabItem` 合并成一份 `SettingsTabDescriptor` 列表平铺渲染。
struct SettingsTabDescriptor: Identifiable, Hashable {
    let id: SettingsTabID
    let title: String
    let systemImage: String
}
