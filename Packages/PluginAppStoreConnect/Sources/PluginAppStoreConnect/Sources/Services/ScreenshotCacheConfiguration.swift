import Foundation
import ProviderDiskCache

enum ScreenshotCacheConfiguration {
    static let pluginName = "AppStoreConnectPlugin"
    /// 迁移期清理用的旧自管缓存目录名（新实现写 App 级 DiskCache 桶）。
    static let legacyCacheDirectoryName = "screenshot-cache"

    static let memoryCostLimit = 32 * 1024 * 1024
    static let networkTimeout: TimeInterval = 30
    static let prefetchConcurrency = 4

    /// 缓存桶治理策略：沿用本插件截图缓存验证过的 200MB → 150MB 水位，
    /// 90 天未访问即过期（与旧的 staleAccessInterval 一致）。
    static let policy = DiskCachePolicy(
        sizeLimit: 200 * 1024 * 1024,
        targetSize: 150 * 1024 * 1024,
        defaultTTL: 90 * 24 * 60 * 60
    )
}
