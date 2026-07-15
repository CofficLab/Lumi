import AppKit
import Foundation
import LumiCoreKit

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

actor ScreenshotImageCache {
    static let shared: ScreenshotImageCache = {
        let root = (lumiCorePluginDataDirectory(for: ScreenshotCacheConfiguration.pluginName)
            ?? lumiCoreFallbackDataRootDirectory.appendingPathComponent(ScreenshotCacheConfiguration.pluginName, isDirectory: true))
            .appendingPathComponent(ScreenshotCacheConfiguration.cacheDirectoryName, isDirectory: true)
        return ScreenshotImageCache(rootDirectory: root)
    }()

    private let diskStore: ScreenshotCacheDiskStore
    private let session: URLSession
    private let memoryCache = MemoryDataCache(limit: ScreenshotCacheConfiguration.memoryCostLimit)
    private var inFlightTasks: [String: Task<Data, Error>] = [:]

    init(rootDirectory: URL, session: URLSession? = nil, diskStore: ScreenshotCacheDiskStore? = nil) {
        self.diskStore = diskStore ?? ScreenshotCacheDiskStore(rootDirectory: rootDirectory)
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = ScreenshotCacheConfiguration.networkTimeout
            configuration.timeoutIntervalForResource = ScreenshotCacheConfiguration.networkTimeout
            self.session = URLSession(configuration: configuration)
        }
    }

    func data(for url: URL, screenshotID: String? = nil) async throws -> Data {
        let key = ScreenshotCacheDiskStore.cacheKey(for: url)

        if let cached = memoryCache.value(forKey: key) {
            diskStore.touchAccess(for: key)
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

    func invalidate(screenshotID: String) {
        diskStore.invalidate(screenshotID: screenshotID)
        memoryCache.removeAll()
    }

    func pruneEntries(keepingURLs: Set<URL>) {
        diskStore.pruneEntries(keepingURLs: keepingURLs)
        memoryCache.removeAll()
    }

    func clear() {
        memoryCache.removeAll()
        diskStore.clear()
    }

    func diskUsage() -> ScreenshotCacheDiskUsage {
        diskStore.diskUsage()
    }

    private func loadData(for url: URL, key: String, screenshotID: String?) async throws -> Data {
        if let diskData = diskStore.readData(for: key), isValidImageData(diskData) {
            diskStore.touchAccess(for: key)
            memoryCache.setValue(diskData, forKey: key)
            return diskData
        }

        if let diskData = diskStore.readData(for: key) {
            diskStore.removeEntry(forKey: key)
            _ = diskData
        }

        let networkData = try await fetchFromNetwork(url: url)
        guard isValidImageData(networkData) else {
            throw ScreenshotImageCacheError.undecodableImage
        }

        memoryCache.setValue(networkData, forKey: key)
        _ = diskStore.store(key: key, sourceURL: url, screenshotID: screenshotID, data: networkData)
        return networkData
    }

    private func fetchFromNetwork(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw ScreenshotImageCacheError.invalidResponse
        }
        return data
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
