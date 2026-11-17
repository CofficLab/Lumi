import AppKit
import Foundation
import ProviderDiskCache
import Testing
@testable import PluginAppStoreConnect

/// 截图缓存落到 App 级 DiskCache 桶：命中、按截图失效、整体清空。
@Suite(.serialized)
struct ScreenshotImageCacheTests {

    private func makeProvider() -> DefaultDiskCacheProvider {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotImageCacheTests-\(UUID().uuidString)", isDirectory: true)
        return DefaultDiskCacheProvider(cacheRootDirectory: root)
    }

    private static func pngData() -> Data {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        return bitmap.flatMap { $0.representation(using: .png, properties: [:]) } ?? Data()
    }

    private static func seed(
        provider: DefaultDiskCacheProvider,
        url: URL,
        screenshotID: String,
        data: Data
    ) async {
        let bucket = await provider.bucket(
            for: AppStoreConnectPluginRuntimeBridge.pluginID,
            policy: ScreenshotCacheConfiguration.policy
        )
        _ = await bucket.store(
            data,
            forKey: ScreenshotImageCache.cacheKey(for: url),
            options: DiskCacheStoreOptions(
                ttl: .useDefault,
                tags: [ScreenshotImageCache.screenshotTag(for: screenshotID)]
            )
        )
    }

    @Test("已落盘到桶里的截图直接命中，不再走网络")
    func readsThroughDiskCacheBucket() async throws {
        let provider = makeProvider()
        let url = URL(string: "https://example.com/preview-1.png")!
        let data = Self.pngData()
        #expect(!data.isEmpty)

        await Self.seed(provider: provider, url: url, screenshotID: "shot-1", data: data)

        let cache = ScreenshotImageCache(diskCache: { provider }, pluginID: AppStoreConnectPluginRuntimeBridge.pluginID)
        let loaded = try await cache.data(for: url, screenshotID: "shot-1")
        #expect(loaded == data)
    }

    @Test("按截图失效后桶里不再有该条目，且无网络时读取失败")
    func invalidateRemovesTaggedEntries() async throws {
        let provider = makeProvider()
        let url = URL(string: "https://example.com/preview-2.png")!
        let data = Self.pngData()

        await Self.seed(provider: provider, url: url, screenshotID: "shot-2", data: data)

        let cache = ScreenshotImageCache(diskCache: { provider }, pluginID: AppStoreConnectPluginRuntimeBridge.pluginID)
        #expect(try await cache.data(for: url, screenshotID: "shot-2") == data)

        await cache.invalidate(screenshotID: "shot-2")

        // 没有网络传输，命中缓存外的路径只能失败——恰好证明条目已被移除。
        await #expect(throws: (any Error).self) {
            _ = try await cache.data(for: url, screenshotID: "shot-2")
        }
    }

    @Test("清空缓存后不再命中")
    func clearEmptiesBucket() async throws {
        let provider = makeProvider()
        let url = URL(string: "https://example.com/preview-3.png")!
        let data = Self.pngData()

        await Self.seed(provider: provider, url: url, screenshotID: "shot-3", data: data)

        let cache = ScreenshotImageCache(diskCache: { provider }, pluginID: AppStoreConnectPluginRuntimeBridge.pluginID)
        #expect(try await cache.data(for: url, screenshotID: "shot-3") == data)

        await cache.clear()

        await #expect(throws: (any Error).self) {
            _ = try await cache.data(for: url, screenshotID: "shot-3")
        }
    }

    @Test("没有 DiskCache Provider 时退化为内存层，不崩溃")
    func worksWithoutDiskCacheProvider() async throws {
        let url = URL(string: "https://example.com/preview-4.png")!
        let cache = ScreenshotImageCache(diskCache: { nil }, pluginID: AppStoreConnectPluginRuntimeBridge.pluginID)

        await #expect(throws: (any Error).self) {
            _ = try await cache.data(for: url, screenshotID: "shot-4")
        }
    }
}
