import Foundation
import SuperLogKit

/// RClick 配置管理器
///
/// 主应用与 LumiFinder 扩展通过 App Group 容器内的 JSON 文件共享配置（`RClickConfig`）。
/// 本地 `RClickPluginLocalStore` 仅作遗留数据迁移与备份。
@MainActor
public class RClickConfigManager: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🖱️"
    public nonisolated static let verbose: Bool = true

    /// 与 `LumiFinder/FinderSync` 保持一致
    public nonisolated static let appGroupId = "group.com.coffic.lumi"
    public nonisolated static let sharedConfigFilename = "RClickConfig.json"
    public nonisolated static let corruptSharedConfigFilename = "RClickConfig.corrupt.json"

    public static let shared = RClickConfigManager()

    private let store: RClickPluginLocalStore
    private let legacyConfigKey = "rClickConfig"
    private let customAppGroupConfigFileURL: URL?
    
    @Published var config: RClickConfig {
        didSet {
            saveConfig()
        }
    }
    
    private convenience init() {
        self.init(appGroupConfigFileURL: nil, store: .shared)
    }

    init(appGroupConfigFileURL: URL?, store: RClickPluginLocalStore) {
        self.customAppGroupConfigFileURL = appGroupConfigFileURL
        self.store = store
        self.config = RClickConfig.default
        loadConfig()
    }
    
    /// 加载配置
    public func loadConfig() {
        if let data = readAppGroupConfigData() {
            if applyLoadedData(data, source: "app_group_file") {
                return
            }
            quarantineAppGroupConfigData()
        }

        guard let legacyData = store.data(forKey: legacyConfigKey) else {
            if Self.verbose, RClickPlugin.verbose {
                RClickPlugin.logger.info("\(Self.t)配置文件不存在，使用默认配置并写入 App Group")
            }
            saveConfig()
            return
        }

        _ = applyLoadedData(legacyData, source: "legacy_local")
        saveConfig()
    }

    /// 保存配置
    @discardableResult
    public func saveConfig() -> Bool {
        do {
            let data = try JSONEncoder().encode(config)
            let appGroupSaved = writeAppGroupConfigData(data)
            let localBackupSaved = store.set(data, forKey: legacyConfigKey)
            if Self.verbose, RClickPlugin.verbose {
                RClickPlugin.logger.info("\(Self.t)💾 已保存配置（App Group + 本地备份）")
            }
            return appGroupSaved && localBackupSaved
        } catch {
            if RClickPlugin.verbose {
                RClickPlugin.logger.error("\(Self.t)❌ 编码配置失败：\(error.localizedDescription)")
            }
            return false
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
    @discardableResult
    public func addTemplate(_ template: NewFileTemplate) -> Bool {
        guard let normalized = template.normalizedForStorage else {
            return false
        }

        config.fileTemplates.append(normalized)
        return true
    }
    
    /// 删除模板
    public func deleteTemplate(at offsets: IndexSet) {
        config.fileTemplates.remove(atOffsets: offsets)
    }
    
    /// 更新模板
    @discardableResult
    public func updateTemplate(_ template: NewFileTemplate) -> Bool {
        guard let normalized = template.normalizedForStorage,
              let index = config.fileTemplates.firstIndex(where: { $0.id == template.id }) else {
            return false
        }

        config.fileTemplates[index] = normalized
        return true
    }
    
    /// 重置为默认配置
    public func resetToDefaults() {
        self.config = RClickConfig.default
    }
    
    /// 清空所有配置
    public func clearAll() {
        store.clearAll()
        removeAppGroupConfigData()
        self.config = RClickConfig.default
        if Self.verbose, RClickPlugin.verbose {
            RClickPlugin.logger.info("\(Self.t)🗑️ 已清空所有配置")
        }
    }

    // MARK: - Private

    nonisolated static func sharedConfigURL(in containerURL: URL) -> URL {
        containerURL.appendingPathComponent(sharedConfigFilename, isDirectory: false)
    }

    nonisolated static func corruptSharedConfigURL(for sharedConfigURL: URL) -> URL {
        sharedConfigURL
            .deletingLastPathComponent()
            .appendingPathComponent(corruptSharedConfigFilename, isDirectory: false)
    }

    private var appGroupConfigFileURL: URL? {
        if let customAppGroupConfigFileURL {
            return customAppGroupConfigFileURL
        }
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId)
            .map(Self.sharedConfigURL)
    }

    private func readAppGroupConfigData() -> Data? {
        guard let fileURL = appGroupConfigFileURL else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    @discardableResult
    private func writeAppGroupConfigData(_ data: Data) -> Bool {
        guard let fileURL = appGroupConfigFileURL else { return false }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            if RClickPlugin.verbose {
                RClickPlugin.logger.error("\(Self.t)❌ 写入 App Group 配置失败：\(error.localizedDescription)")
            }
            return false
        }
    }

    private func removeAppGroupConfigData() {
        guard let fileURL = appGroupConfigFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func applyLoadedData(_ data: Data, source: String) -> Bool {
        do {
            let decoded = try JSONDecoder().decode(RClickConfig.self, from: data)
            self.config = decoded.normalizedForStorage
            if Self.verbose, RClickPlugin.verbose {
                RClickPlugin.logger.info(
                    "\(Self.t)已加载配置（\(source)）：\(self.config.items.count) 个菜单项，\(self.config.fileTemplates.count) 个模板"
                )
            }
            return true
        } catch {
            if RClickPlugin.verbose {
                RClickPlugin.logger.error("\(Self.t)❌ 解码配置失败：\(error.localizedDescription)")
            }
            return false
        }
    }

    private func quarantineAppGroupConfigData() {
        guard let fileURL = appGroupConfigFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let corruptURL = Self.corruptSharedConfigURL(for: fileURL)
        do {
            if FileManager.default.fileExists(atPath: corruptURL.path) {
                try FileManager.default.removeItem(at: corruptURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: corruptURL)
        } catch {
            if RClickPlugin.verbose {
                RClickPlugin.logger.error("\(Self.t)❌ 隔离损坏 App Group 配置失败：\(error.localizedDescription)")
            }
        }
    }
}
