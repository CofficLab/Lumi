import Foundation
import Combine

/// 插件设置 VM：管理插件的启用/禁用状态。
@MainActor
final class PluginSettingsVM: ObservableObject {
    /// 全局单例
    static let shared = PluginSettingsVM()

    private let userDefaultsKey = "SwiftUI_Template_PluginSettings"

    /// 发布设置变化，让订阅者能够实时响应
    @Published private(set) var settings: [String: Bool] = [:]

    private init() {
        self.settings = loadSettings()
    }

    /// 获取插件的启用状态
    func isPluginEnabled(_ pluginId: String) -> Bool {
        settings[pluginId] ?? false
    }

    /// 设置插件的启用状态
    func setPluginEnabled(_ pluginId: String, enabled: Bool) {
        settings[pluginId] = enabled
        saveSettings(settings)

        // 发送通知，通知 UI 更新
        NotificationCenter.default.post(name: .pluginSettingsChanged, object: nil)
    }

    private func loadSettings() -> [String: Bool] {
        PluginStateStore.shared.object(forKey: userDefaultsKey) as? [String: Bool] ?? [:]
    }

    private func saveSettings(_ settings: [String: Bool]) {
        PluginStateStore.shared.set(settings, forKey: userDefaultsKey)
    }
}

