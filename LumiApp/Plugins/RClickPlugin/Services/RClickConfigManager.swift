import Foundation
import MagicKit

/// RClick 配置管理器
///
/// 使用 RClickPluginLocalStore 持久化配置数据。
/// 配置以 Data 形式存储在 settings.plist 中，使用 JSON 编码保持与模型的可读性。
@MainActor
class RClickConfigManager: ObservableObject, SuperLog {
    nonisolated static let emoji = "🖱️"
    nonisolated static let verbose: Bool = false
    
    static let shared = RClickConfigManager()
    
    private let store = RClickPluginLocalStore.shared
    private let configKey = "rClickConfig"
    
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
    func loadConfig() {
        guard let data = store.data(forKey: configKey) else {
            if Self.verbose {
                RClickPlugin.logger.info("\(Self.t)配置文件不存在，使用默认配置")
            }
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode(RClickConfig.self, from: data)
            self.config = decoded
            if Self.verbose {
                RClickPlugin.logger.info("\(Self.t)已加载配置：\(self.config.items.count) 个菜单项，\(self.config.fileTemplates.count) 个模板")
            }
        } catch {
            RClickPlugin.logger.error("\(Self.t)❌ 解码配置失败：\(error.localizedDescription)")
            self.config = RClickConfig.default
        }
    }
    
    /// 保存配置
    func saveConfig() {
        do {
            let data = try JSONEncoder().encode(config)
            store.set(data, forKey: configKey)
            if Self.verbose {
                RClickPlugin.logger.info("\(Self.t)💾 已保存配置")
            }
        } catch {
            RClickPlugin.logger.error("\(Self.t)❌ 编码配置失败：\(error.localizedDescription)")
        }
    }
    
    /// 切换菜单项启用状态
    func toggleItem(_ item: RClickMenuItem) {
        if let index = config.items.firstIndex(where: { $0.id == item.id }) {
            config.items[index].isEnabled.toggle()
        }
    }
    
    // MARK: - Template Management
    
    /// 切换模板启用状态
    func toggleTemplate(_ template: NewFileTemplate) {
        if let index = config.fileTemplates.firstIndex(where: { $0.id == template.id }) {
            config.fileTemplates[index].isEnabled.toggle()
        }
    }
    
    /// 添加模板
    func addTemplate(_ template: NewFileTemplate) {
        config.fileTemplates.append(template)
    }
    
    /// 删除模板
    func deleteTemplate(at offsets: IndexSet) {
        config.fileTemplates.remove(atOffsets: offsets)
    }
    
    /// 更新模板
    func updateTemplate(_ template: NewFileTemplate) {
        if let index = config.fileTemplates.firstIndex(where: { $0.id == template.id }) {
            config.fileTemplates[index] = template
        }
    }
    
    /// 重置为默认配置
    func resetToDefaults() {
        self.config = RClickConfig.default
    }
    
    /// 清空所有配置
    func clearAll() {
        store.clearAll()
        self.config = RClickConfig.default
        if Self.verbose {
            RClickPlugin.logger.info("\(Self.t)🗑️ 已清空所有配置")
        }
    }
}
