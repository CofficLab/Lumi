import Foundation
import SuperLogKit

/// RClick 配置管理器
///
/// 主应用与 LumiFinder 扩展通过 App Group `UserDefaults` 共享配置（`RClickConfig`）。
/// 本地 `RClickPluginLocalStore` 仅作遗留数据迁移与备份。
@MainActor
public class RClickConfigManager: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🖱️"
    public nonisolated static let verbose: Bool = true

    /// 与 `LumiFinder/FinderSync` 保持一致
    public nonisolated static let appGroupId = "group.com.coffic.lumi"
    public nonisolated static let sharedConfigKey = "RClickConfig"

    public static let shared = RClickConfigManager()

    private let store = RClickPluginLocalStore.shared
    private let legacyConfigKey = "rClickConfig"
    
    @Published var config: RClickConfig {
        didSet {
            saveConfig()
        }
    }
    
    private init() {
        self.config = RClickConfig.default
        loadConfig()
    }
    
    /// 加载配置
    public func loadConfig() {
        if let data = appGroupDefaults?.data(forKey: Self.sharedConfigKey) {
            applyLoadedData(data, source: "app_group")
            return
        }

        guard let legacyData = store.data(forKey: legacyConfigKey) else {
            if Self.verbose, RClickPlugin.verbose {
                RClickPlugin.logger.info("\(Self.t)配置文件不存在，使用默认配置并写入 App Group")
            }
            saveConfig()
            return
        }

        applyLoadedData(legacyData, source: "legacy_local")
        saveConfig()
    }

    /// 保存配置
    public func saveConfig() {
        do {
            let data = try JSONEncoder().encode(config)
            appGroupDefaults?.set(data, forKey: Self.sharedConfigKey)
            store.set(data, forKey: legacyConfigKey)
            if Self.verbose, RClickPlugin.verbose {
                RClickPlugin.logger.info("\(Self.t)💾 已保存配置（App Group + 本地备份）")
            }
        } catch {
            if RClickPlugin.verbose {
                RClickPlugin.logger.error("\(Self.t)❌ 编码配置失败：\(error.localizedDescription)")
            }
        }
    }
    
    /// 切换菜单项启用状态
    public func toggleItem(_ item: RClickMenuItem) {
        if let index = config.items.firstIndex(where: { $0.id == item.id }) {
            config.items[index].isEnabled.toggle()
        }
    }
    
    // MARK: - Template Management
    
    /// 切换模板启用状态
    public func toggleTemplate(_ template: NewFileTemplate) {
        if let index = config.fileTemplates.firstIndex(where: { $0.id == template.id }) {
            config.fileTemplates[index].isEnabled.toggle()
        }
    }
    
    /// 添加模板
    public func addTemplate(_ template: NewFileTemplate) {
        config.fileTemplates.append(template)
    }
    
    /// 删除模板
    public func deleteTemplate(at offsets: IndexSet) {
        config.fileTemplates.remove(atOffsets: offsets)
    }
    
    /// 更新模板
    public func updateTemplate(_ template: NewFileTemplate) {
        if let index = config.fileTemplates.firstIndex(where: { $0.id == template.id }) {
            config.fileTemplates[index] = template
        }
    }
    
    /// 重置为默认配置
    public func resetToDefaults() {
        self.config = RClickConfig.default
    }
    
    /// 清空所有配置
    public func clearAll() {
        store.clearAll()
        appGroupDefaults?.removeObject(forKey: Self.sharedConfigKey)
        self.config = RClickConfig.default
        if Self.verbose, RClickPlugin.verbose {
            RClickPlugin.logger.info("\(Self.t)🗑️ 已清空所有配置")
        }
    }

    // MARK: - Private

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupId)
    }

    private func applyLoadedData(_ data: Data, source: String) {
        do {
            let decoded = try JSONDecoder().decode(RClickConfig.self, from: data)
            self.config = decoded
            if Self.verbose, RClickPlugin.verbose {
                RClickPlugin.logger.info(
                    "\(Self.t)已加载配置（\(source)）：\(self.config.items.count) 个菜单项，\(self.config.fileTemplates.count) 个模板"
                )
            }
        } catch {
            if RClickPlugin.verbose {
                RClickPlugin.logger.error("\(Self.t)❌ 解码配置失败：\(error.localizedDescription)")
            }
            self.config = RClickConfig.default
        }
    }
}
