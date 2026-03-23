import Foundation

/// 插件设置 VM：管理插件的启用/禁用状态。
@MainActor
final class PluginSettingsVM: ObservableObject {
    /// 全局单例
    static let shared = PluginSettingsVM()

    private let userDefaultsKey = "SwiftUI_Template_PluginSettings"

    /// 发布设置变化，让订阅者能够实时响应
    @Published private(set) var settings: [String: Bool] = [:]

    /// 获取插件的启用状态
    func isPluginEnabled(_ pluginId: String) -> Bool {
        settings[pluginId] ?? false
    }

    /// 设置插件的启用状态
    func setPluginEnabled(_ pluginId: String, enabled: Bool) {
        settings[pluginId] = enabled

        // 发送通知，通知 UI 更新
        NotificationCenter.default.post(name: .pluginSettingsChanged, object: nil)
    }
}

