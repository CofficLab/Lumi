import Foundation

// MARK: - Settings Tab Selection

/// 设置面板的 tab 选择器。
///
/// 所有设置标签(General / Appearance / About / 插件管理等)均由插件
/// 通过 `settingsTabItems(kernel:)` 贡献,不再有"宿主内置"特例。
/// 此处仅保留扁平描述符,供侧边栏渲染。
typealias SettingsTabID = String

/// 侧边栏显示一个 tab 所需的扁平数据。
struct SettingsTabDescriptor: Identifiable, Hashable {
    let id: SettingsTabID
    let title: String
    let systemImage: String
}
