import Foundation
import SuperLogKit
import os

/// LSP 配置注册表
///
/// 纯注册表模式：语言服务器配置由各语言插件通过 `registerServerConfig` 注册，
/// `LSPConfig` 不再硬编码任何语言特定的发现逻辑。
public struct LSPConfig: SuperLog {
    public nonisolated static let emoji = "⚙️"

    // MARK: - Server Config Type

    /// 语言服务器二进制配置
    public struct ServerConfig: Sendable, Equatable {
        public let languageId: String
        public let execPath: String
        public let arguments: [String]
        public let env: [String: String]

        public init(
            languageId: String,
            execPath: String,
            arguments: [String] = [],
            env: [String: String] = [:]
        ) {
            self.languageId = languageId
            self.execPath = execPath
            self.arguments = arguments
            self.env = env
        }
    }

    // MARK: - Registry

    /// 服务器配置发现函数（languageId → provider）
    /// provider 在实际需要时才被调用，返回该语言的服务器配置
    /// 使用 nonisolated(unsafe) 标注，线程安全由 registryLock 保证
    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var _providers: [String: @Sendable () -> ServerConfig?] = [:]

    /// 注册语言服务器发现函数
    ///
    /// 由语言插件在初始化时调用，注册特定语言的服务器配置发现逻辑。
    /// provider 闭包在实际需要配置时才被调用（延迟执行），不会阻塞启动。
    /// - Parameters:
    ///   - languageId: 语言 ID（如 "go", "python", "typescript"）
    ///   - provider: 返回服务器配置的闭包，如果环境不满足则返回 nil
    public static func registerServerProvider(
        for languageId: String,
        provider: @escaping @Sendable () -> ServerConfig?
    ) {
        registryLock.lock()
        _providers[languageId] = provider
        // 清除该语言的缓存，以便下次查询时重新发现
        _pathCache[languageId] = nil
        registryLock.unlock()
    }

    /// 注册语言服务器配置（静态版本，用于已知路径的场景）
    ///
    /// - Parameters:
    ///   - languageId: 语言 ID
    ///   - config: 服务器配置
    public static func registerServerConfig(for languageId: String, config: ServerConfig) {
        registerServerProvider(for: languageId) { config }
    }

    /// 查询已注册的服务器配置
    ///
    /// 调用已注册的 provider 获取配置。
    /// - Parameter languageId: 语言 ID
    /// - Returns: 服务器配置，如果未注册或 provider 返回 nil 则返回 nil
    public static func serverConfig(for languageId: String) -> ServerConfig? {
        registryLock.lock()
        let provider = _providers[languageId]
        registryLock.unlock()
        return provider?()
    }

    /// 获取所有已注册的语言 ID
    public static var registeredLanguageIds: [String] {
        registryLock.lock()
        let ids = Array(_providers.keys)
        registryLock.unlock()
        return ids.sorted()
    }

    /// 检查指定语言是否已注册服务器配置
    public static func isRegistered(for languageId: String) -> Bool {
        registryLock.lock()
        let registered = _providers[languageId] != nil
        registryLock.unlock()
        return registered
    }

    // MARK: - Cache

    /// 路径检测结果缓存（languageId → 路径或 nil）
    /// 避免重复 fork 子进程检测服务器路径
    /// 使用 nonisolated(unsafe) 标注，实际线程安全由 pathCacheLock 保证
    private static let pathCacheLock = NSLock()
    nonisolated(unsafe) private static var _pathCache: [String: String?] = [:]

    /// 缓存是否已经执行过完整扫描
    nonisolated(unsafe) private static var _fullScanCompleted = false

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "lsp.config")

    // MARK: - Async Cache Warmup

    /// 在后台线程执行所有已注册语言的可用性检测，结果写入缓存。
    /// 调用方应在非主线程调用此方法（如 Task.detached）。
    @discardableResult
    public static func warmUpCacheInBackground() async -> Bool {
        let languageIds = registeredLanguageIds
        guard !languageIds.isEmpty else {
            return false
        }

        return await Task.detached(priority: .utility) {
            var available = false
            for languageId in languageIds {
                if let config = serverConfig(for: languageId), !config.execPath.isEmpty {
                    // 缓存路径
                    cacheServerPath(for: languageId, path: config.execPath)
                    available = true
                }
            }
            setFullScanCompleted(true)
            return available
        }.value
    }

    /// 缓存服务器路径（同步方法，用于在异步上下文中调用）
    private static func cacheServerPath(for languageId: String, path: String) {
        pathCacheLock.lock()
        _pathCache[languageId] = path
        pathCacheLock.unlock()
    }

    /// 设置完整扫描状态（同步方法，用于在异步上下文中调用）
    private static func setFullScanCompleted(_ completed: Bool) {
        pathCacheLock.lock()
        _fullScanCompleted = completed
        pathCacheLock.unlock()
    }

    /// 重置缓存（用于测试或服务器安装变更后刷新）
    public static func resetCache() {
        pathCacheLock.lock()
        _pathCache.removeAll()
        _fullScanCompleted = false
        pathCacheLock.unlock()
    }

    /// 重置注册表和缓存（用于测试）
    public static func resetAll() {
        registryLock.lock()
        _providers.removeAll()
        registryLock.unlock()
        resetCache()
    }
}
