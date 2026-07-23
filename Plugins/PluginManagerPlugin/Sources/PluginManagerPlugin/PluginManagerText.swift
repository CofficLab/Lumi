import Foundation
import LocalizationKit

/// 插件管理页用到的本地化字符串键集中管理。
///
/// 统一通过 `LumiLocalization.string(_:bundle:)` 在本插件 bundle 的
/// `Localizable.xcstrings` 中查找;键即英文文案,缺失时回退到键本身。
enum PluginManagerText {
    static let plugins = "Plugins"
    static let pluginsHint = "Manage all registered plugins"
    static let aboutDescription = "Lists and manages all plugins registered with the kernel. Toggle a plugin to enable or disable it at runtime."
    static let searchPlugins = "Search plugins"
    static let noPluginsFound = "No plugins found"
    static let selectPlugin = "Select a plugin"
    static let pluginsCount = "%lld Plugins"
    static let enabledCount = "%lld enabled"
    static let allCategories = "All"
    static let alwaysOn = "Always On"
    static let disabled = "Disabled"
    static let enabled = "Enabled"
    static let order = "Order: %d"
    static let noDetailsProvided = "No details provided"
    static let noDetailsHint = "The plugin author did not provide a details view."
    static let enable = "Enable"

    /// 查找本地化字符串,缺失回退到 key。
    static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: .module)
    }
}
