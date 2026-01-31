import Foundation

/// 插件设置存储：管理插件的启用/禁用状态
class PluginSettingsStore {
    static let shared = PluginSettingsStore()

    private let userDefaultsKey = "SwiftUI_Template_PluginSettings"

    private init() {}

    /// 获取插件的启用状态
    /// - Parameter pluginId: 插件ID
    /// - Returns: true 表示启用，false 表示禁用
    func isPluginEnabled(_ pluginId: String) -> Bool {
        let settings = loadSettings()
        // 如果没有设置，默认启用
        return settings[pluginId] ?? true
    }

    /// 设置插件的启用状态
    /// - Parameters:
    ///   - pluginId: 插件ID
    ///   - enabled: true 表示启用，false 表示禁用
    func setPluginEnabled(_ pluginId: String, enabled: Bool) {
        var settings = loadSettings()
        settings[pluginId] = enabled
        saveSettings(settings)
    }

    /// 加载所有插件设置
    private func loadSettings() -> [String: Bool] {
        UserDefaults.standard.object(forKey: userDefaultsKey) as? [String: Bool] ?? [:]
    }

    /// 保存插件设置
    private func saveSettings(_ settings: [String: Bool]) {
        UserDefaults.standard.set(settings, forKey: userDefaultsKey)
    }
}

/// 插件信息模型
struct PluginInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    /// 插件是否开发者启用（检查插件的 static let enable 属性）
    let isDeveloperEnabled: () -> Bool

    init(id: String, name: String, description: String, icon: String = "puzzlepiece.extension", isDeveloperEnabled: @escaping () -> Bool = { true }) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.isDeveloperEnabled = isDeveloperEnabled
    }
}
