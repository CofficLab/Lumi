import Foundation

/// 插件管理列表的启用状态筛选条件。
enum PluginManagementFilter: CaseIterable {
    /// 不过滤启用状态。
    case all
    /// 仅展示已启用的插件。
    case enabled
    /// 仅展示未启用的插件。
    case disabled

    var title: String {
        switch self {
        case .all: PluginPluginManagerText.filterAll
        case .enabled: PluginPluginManagerText.filterEnabled
        case .disabled: PluginPluginManagerText.filterDisabled
        }
    }

    /// 指定启用状态是否命中当前筛选条件。
    func matches(isEnabled: Bool) -> Bool {
        switch self {
        case .all: true
        case .enabled: isEnabled
        case .disabled: !isEnabled
        }
    }
}
