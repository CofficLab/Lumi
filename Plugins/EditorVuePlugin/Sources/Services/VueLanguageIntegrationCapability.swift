import Foundation
import EditorService
import os
import SuperLogKit

/// Vue 语言集成能力
///
/// 注册为 `SuperEditorLanguageIntegrationCapability`，让内核 LSPService
/// 知道当打开 `.vue` 文件时需要启动 Volar Language Server。
///
/// **集成流程**：
/// 1. `supports()` 检查项目是否为 Vue 项目并验证 Volar 可用性
/// 2. `workspaceFolders()` 提供项目根目录作为 workspace
/// 3. `initializationOptions()` 注入 Volar 混合模式配置和 Vue 版本
/// 4. 内核 LSPService 负责实际的进程启动和 JSON-RPC 通信
@MainActor
final class VueLanguageIntegrationCapability: SuperEditorLanguageIntegrationCapability, SuperLog {
    nonisolated static let emoji = "🟢"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.language-integration"
    )

    let id = "VueLanguageIntegration"
    let priority = 10

    /// 支持的语言 ID
    private let supportedLanguageIds: Set<String> = ["vue"]

    private static let maxHealthCacheEntries = 32

    /// 缓存 Volar 健康检查结果
    private var healthCache: [String: VolarServiceManager.ServiceHealth] = [:]
    private var healthCacheOrder: [String] = []

    func supports(languageId: String, projectPath: String?) -> Bool {
        guard supportedLanguageIds.contains(languageId) else { return false }
        guard let projectPath else { return false }
        let cacheKey = normalizedProjectPath(projectPath)

        // 基础检查：package.json 是否存在
        let packageJSONPath = (cacheKey as NSString).appendingPathComponent("package.json")
        guard FileManager.default.fileExists(atPath: packageJSONPath) else { return false }

        // Volar 健康检查（带缓存，避免每次打开文件都检查）
        let health: VolarServiceManager.ServiceHealth
        if let cached = healthCache[cacheKey] {
            touchHealthCacheEntry(cacheKey)
            health = cached
        } else {
            health = VolarServiceManager.checkHealth(projectPath: cacheKey)
            setHealthCache(health, for: cacheKey)
        }

        switch health {
        case .ready:
            return true
        case .notApplicable:
            return false
        case .nodeNotFound:
            if EditorVuePlugin.verbose {
                Self.logger.warning("\(Self.t)\(Self.emoji) Node.js 未找到，Volar 不可用")
            }
            // 仍然返回 true，让基础静态补全功能工作
            // LSP 服务启动会失败但不会阻塞编辑器
            return true
        case .volarNotFound:
            if EditorVuePlugin.verbose {
                Self.logger.warning("\(Self.t)\(Self.emoji) Volar 未安装，降级为静态补全")
            }
            return true
        case .vueNotFound:
            if EditorVuePlugin.verbose {
                Self.logger.warning("\(Self.t)\(Self.emoji) Vue 依赖未找到，降级为静态补全")
            }
            return true
        }
    }

    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]? {
        // Volar 使用项目根目录作为 workspace
        let uri = URL(fileURLWithPath: projectPath).absoluteString
        let name = URL(fileURLWithPath: projectPath).lastPathComponent
        return [EditorWorkspaceFolder(uri: uri, name: name)]
    }

    func serverConfig(for languageId: String, projectPath: String?) -> LSPConfig.ServerConfig? {
        guard languageId == "vue", let projectPath,
              let config = VolarServiceManager.serverConfig(projectPath: projectPath) else {
            return nil
        }

        let serverPath = (projectPath as NSString).appendingPathComponent(config.serverBinary)
        return LSPConfig.ServerConfig(
            languageId: "vue",
            execPath: config.nodePath,
            arguments: [serverPath, "--stdio"]
        )
    }

    func initializationOptions(for languageId: String, projectPath: String) -> [String : String]? {
        // 尝试从 VolarServiceManager 获取完整配置
        if let config = VolarServiceManager.serverConfig(projectPath: projectPath) {
            if EditorVuePlugin.verbose {
                Self.logger.info("\(Self.t)\(Self.emoji) 使用 VolarServiceManager 配置: vue=\(config.vueVersion.rawValue), hybrid=\(config.hybridMode)")
            }
            return config.initializationOptions
        }

        // 降级：直接从 VueVersionDetector 获取版本信息
        let version = VueVersionDetector.detect(at: projectPath)

        if EditorVuePlugin.verbose {
            Self.logger.info("\(Self.t)\(Self.emoji) 使用降级配置: vue=\(version.rawValue)")
        }

        return [
            "vue.server.hybridMode": "true",
            "vueVersion": version.rawValue == "vue2" ? "2" : "3",
        ]
    }

    /// 清除指定项目的健康检查缓存
    func invalidateCache(projectPath: String) {
        let cacheKey = normalizedProjectPath(projectPath)
        healthCache.removeValue(forKey: cacheKey)
        healthCacheOrder.removeAll { $0 == cacheKey }
    }

    /// 清除所有缓存
    func invalidateAllCache() {
        healthCache.removeAll()
        healthCacheOrder.removeAll()
    }

    private func normalizedProjectPath(_ projectPath: String) -> String {
        URL(fileURLWithPath: projectPath).standardizedFileURL.path
    }

    private func setHealthCache(_ health: VolarServiceManager.ServiceHealth, for projectPath: String) {
        healthCache[projectPath] = health
        touchHealthCacheEntry(projectPath)

        while healthCacheOrder.count > Self.maxHealthCacheEntries {
            let removedProjectPath = healthCacheOrder.removeFirst()
            healthCache.removeValue(forKey: removedProjectPath)
        }
    }

    private func touchHealthCacheEntry(_ projectPath: String) {
        healthCacheOrder.removeAll { $0 == projectPath }
        healthCacheOrder.append(projectPath)
    }
}
