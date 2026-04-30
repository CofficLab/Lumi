import Foundation

/// 插件设置 VM：管理插件的启用/禁用状态。
///
/// Phase 3: 统一 App 插件和 Editor 插件的配置存储。
/// 旧版 Editor 插件配置（`EditorConfigStore`）会在首次访问时自动迁移。
@MainActor
final class PluginSettingsVM: ObservableObject {
    /// 全局单例
    static let shared = PluginSettingsVM()

    /// 发布设置变化，让订阅者能够实时响应
    @Published private(set) var settings: [String: Bool] = [:]

    /// 是否已完成旧版 Editor 插件配置迁移
    private var hasMigratedEditorConfig = false

    /// 初始化时从持久化存储加载插件状态
    private init() {
        settings = AppSettingStore.loadPluginSettings()
    }

    /// 迁移旧版 Editor 插件配置（一次性）
    ///
    /// 从 `EditorConfigStore` 读取旧的 editor 插件开关状态，
    /// 写入 `AppSettingStore`，确保用户设置不丢失。
    private func migrateEditorConfigIfNeeded() {
        guard !hasMigratedEditorConfig else { return }
        hasMigratedEditorConfig = true

        // 直接从 EditorConfigStore 的 plist 读取旧设置
        let oldDict = EditorConfigStore.loadAllSettings()
        let prefix = "editorPluginEnabled."
        var migrated = false

        for (oldKey, value) in oldDict {
            guard oldKey.hasPrefix(prefix), let enabled = value as? Bool else { continue }
            let pluginID = String(oldKey.dropFirst(prefix.count))
            // 只迁移新存储中不存在的 key
            if settings[pluginID] == nil {
                settings[pluginID] = enabled
                AppSettingStore.savePluginEnabled(pluginID, enabled: enabled)
                migrated = true
            }
        }

        if migrated {
            objectWillChange.send()
        }
    }

    /// 获取插件的启用状态
    func isPluginEnabled(_ pluginId: String) -> Bool {
        migrateEditorConfigIfNeeded()
        return settings[pluginId] ?? false
    }

    /// 设置插件的启用状态
    func setPluginEnabled(_ pluginId: String, enabled: Bool) {
        migrateEditorConfigIfNeeded()
        settings[pluginId] = enabled
        
        // 持久化到存储
        AppSettingStore.savePluginEnabled(pluginId, enabled: enabled)

        // 发送通知，通知 UI 更新
        NotificationCenter.default.post(name: .pluginSettingsChanged, object: nil)
    }
}