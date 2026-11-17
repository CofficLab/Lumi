import AppKit
import CryptoKit
import Foundation
import KernelCore
import KitAgentTool
import KitAppStorePromo
import LumiLocalizationKit
import LumiLoggingKit
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderDiskCache
import ProviderDocsView
import ProviderNetwork
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToolbar
import ProviderToolManager
enum ScreenshotImageCacheError: LocalizedError {
    case invalidResponse
    case undecodableImage

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return AppStoreConnectLocalization.string("The screenshot image could not be downloaded.")
        case .undecodableImage:
            return AppStoreConnectLocalization.string("The screenshot image data is invalid.")
        }
    }
}

/// 截图预览图缓存：内存层 + App 级 `DiskCacheProviding` 桶。
///
/// 落盘、TTL 过期与 LRU 淘汰统一由 DiskCache 桶治理；本类只补齐截图语义：
/// 按 URL 摘要做 key、内存热层、同 key 并发去重与图片有效性校验。
actor ScreenshotImageCache {
    static let shared = ScreenshotImageCache(
        diskCache: { AppStoreConnectPluginRuntimeBridge.diskCacheProvider },
        pluginID: AppStoreConnectPluginRuntimeBridge.pluginID
    )

    private let diskCache: (@Sendable () -> (any DiskCacheProviding)?)?
    private let pluginID: String
    private var bucketHandle: (any DiskCacheBucket)?
    private var network: (any NetworkProviding)?
    private let memoryCache = MemoryDataCache(limit: ScreenshotCacheConfiguration.memoryCostLimit)
    private var inFlightTasks: [String: Task<Data, Error>] = [:]

    init(
        diskCache: (@Sendable () -> (any DiskCacheProviding)?)? = nil,
        pluginID: String = AppStoreConnectPluginRuntimeBridge.pluginID,
        network: (any NetworkProviding)? = nil
    ) {
        self.diskCache = diskCache
        self.pluginID = pluginID
        self.network = network
    }

    func configure(network: any NetworkProviding) {
        self.network = network
    }

    func data(for url: URL, screenshotID: String? = nil) async throws -> Data {
        let key = Self.cacheKey(for: url)

        if let cached = memoryCache.value(forKey: key) {
            return cached
        }

        if let task = inFlightTasks[key] {
            return try await task.value
        }

        let task = Task<Data, Error> {
            try await self.loadData(for: url, key: key, screenshotID: screenshotID)
        }
        inFlightTasks[key] = task

        defer { inFlightTasks[key] = nil }

        return try await task.value
    }

    func prefetch(urls: [(url: URL, screenshotID: String?)]) async {
        let unique = Dictionary(
            urls.map { ($0.url.absoluteString, $0) },
            uniquingKeysWith: { first, _ in first }
        ).values

        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            for item in unique {
                if activeCount >= ScreenshotCacheConfiguration.prefetchConcurrency {
                    await group.next()
                    activeCount -= 1
                }
                activeCount += 1
                group.addTask {
                    _ = try? await self.data(for: item.url, screenshotID: item.screenshotID)
                }
            }
        }
    }

    /// 失效某张截图的所有缓存条目（截图被替换或删除时调用）。
    func invalidate(screenshotID: String) async {
        memoryCache.removeAll()
        await bucket()?.invalidate(tag: Self.screenshotTag(for: screenshotID))
    }

    func clear() async {
        memoryCache.removeAll()
        await bucket()?.clear()
    }

    static func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func screenshotTag(for screenshotID: String) -> String {
        "screenshot:\(screenshotID)"
    }

    /// 首次使用时向 Provider 取桶；Provider 缺失时返回 nil，缓存退化为内存层。
    private func bucket() async -> (any DiskCacheBucket)? {
        if let bucketHandle {
            return bucketHandle
        }
        guard let diskCache, let provider = diskCache() else { return nil }
        let bucket = await provider.bucket(
            for: pluginID,
            policy: ScreenshotCacheConfiguration.policy
        )
        bucketHandle = bucket
        return bucket
    }

    private func loadData(for url: URL, key: String, screenshotID: String?) async throws -> Data {
        let bucket = await bucket()

        if let diskData = await bucket?.data(forKey: key) {
            guard isValidImageData(diskData) else {
                await bucket?.remove(forKey: key)
                return try await downloadAndStore(url: url, key: key, screenshotID: screenshotID, bucket: bucket)
            }
            memoryCache.setValue(diskData, forKey: key)
            return diskData
        }

        return try await downloadAndStore(url: url, key: key, screenshotID: screenshotID, bucket: bucket)
    }

    private func downloadAndStore(
        url: URL,
        key: String,
        screenshotID: String?,
        bucket: (any DiskCacheBucket)?
    ) async throws -> Data {
        let networkData = try await fetchFromNetwork(url: url)
        guard isValidImageData(networkData) else {
            throw ScreenshotImageCacheError.undecodableImage
        }

        memoryCache.setValue(networkData, forKey: key)
        if let bucket {
            let tags = screenshotID.map { [Self.screenshotTag(for: $0)] } ?? []
            _ = await bucket.store(
                networkData,
                forKey: key,
                options: DiskCacheStoreOptions(ttl: .useDefault, tags: tags)
            )
        }
        return networkData
    }

    private func fetchFromNetwork(url: URL) async throws -> Data {
        if let network {
            do {
                return try await network.get(
                    url: url,
                    timeout: ScreenshotCacheConfiguration.networkTimeout
                ).body
            } catch {
                throw ScreenshotImageCacheError.invalidResponse
            }
        }

        throw ScreenshotImageCacheError.invalidResponse
    }

    private func isValidImageData(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        return NSImage(data: data) != nil
    }
}

private final class MemoryDataCache: @unchecked Sendable {
    private let cache = NSCache<NSString, NSData>()

    init(limit: Int) {
        cache.totalCostLimit = limit
    }

    func value(forKey key: String) -> Data? {
        cache.object(forKey: key as NSString) as Data?
    }

    func setValue(_ data: Data, forKey key: String) {
        cache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
