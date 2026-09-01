import Foundation

enum ScreenshotCacheConfiguration {
    static let pluginName = "AppStoreConnectPlugin"
    static let cacheDirectoryName = "screenshot-cache"
    static let objectsDirectoryName = "objects"
    static let manifestFileName = "manifest.json"

    static let memoryCostLimit = 32 * 1024 * 1024
    static let diskByteLimit: Int64 = 200 * 1024 * 1024
    static let diskTargetByteCount: Int64 = 150 * 1024 * 1024
    static let staleAccessInterval: TimeInterval = 90 * 24 * 60 * 60
    static let networkTimeout: TimeInterval = 30
    static let prefetchConcurrency = 4
}
