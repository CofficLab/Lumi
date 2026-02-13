import Foundation

/// 项目配置模型
struct ProjectConfig: Codable, Identifiable, Equatable {
    let id: UUID
    let projectPath: String
    var providerId: String
    var model: String
    var createdAt: Date
    var updatedAt: Date

    init(projectPath: String, providerId: String = "anthropic", model: String = "") {
        self.id = UUID()
        self.projectPath = projectPath
        self.providerId = providerId
        self.model = model
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 获取项目名称
    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }
}

/// 项目配置存储管理器
@MainActor
class ProjectConfigStore {
    /// 单例
    static let shared = ProjectConfigStore()

    private let userDefaultsKey = "ProjectConfigs"

    private init() {}

    /// 获取所有项目配置
    func getAllConfigs() -> [ProjectConfig] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let configs = try? JSONDecoder().decode([ProjectConfig].self, from: data) else {
            return []
        }
        return configs
    }

    /// 获取特定项目的配置
    func getConfig(for projectPath: String) -> ProjectConfig? {
        return getAllConfigs().first { $0.projectPath == projectPath }
    }

    /// 保存或更新项目配置
    func saveConfig(_ config: ProjectConfig) {
        var configs = getAllConfigs()

        // 移除旧配置（如果存在）
        configs.removeAll { $0.projectPath == config.projectPath }

        // 更新时间戳
        var updatedConfig = config
        updatedConfig.updatedAt = Date()

        // 添加新配置
        configs.append(updatedConfig)

        // 保存到 UserDefaults
        if let encoded = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    /// 删除项目配置
    func deleteConfig(for projectPath: String) {
        var configs = getAllConfigs()
        configs.removeAll { $0.projectPath == projectPath }

        if let encoded = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    /// 获取或创建项目配置
    func getOrCreateConfig(for projectPath: String, defaultProviderId: String = "anthropic", defaultModel: String = "") -> ProjectConfig {
        if let existing = getConfig(for: projectPath) {
            return existing
        }

        // 创建默认配置
        let newConfig = ProjectConfig(
            projectPath: projectPath,
            providerId: defaultProviderId,
            model: defaultModel
        )
        saveConfig(newConfig)
        return newConfig
    }
}
