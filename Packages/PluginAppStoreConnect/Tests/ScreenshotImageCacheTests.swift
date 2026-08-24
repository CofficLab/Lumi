import Foundation
import Testing
@testable import AppStoreConnectPlugin

@Suite("Screenshot image cache", .serialized)
struct ScreenshotImageCacheTests {
    private static let samplePNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    @Test("reads from disk without additional network requests")
    func diskHitAvoidsNetwork() async throws {
        ScreenshotCacheMockURLProtocol.reset()
        defer { ScreenshotCacheMockURLProtocol.reset() }

        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = URL(string: "https://example.com/screenshot-a.png")!
        let key = ScreenshotCacheDiskStore.cacheKey(for: url)
        let diskStore = ScreenshotCacheDiskStore(rootDirectory: directory)
        #expect(diskStore.store(key: key, sourceURL: url, screenshotID: "shot-a", data: Self.samplePNG))

        let requestCounter = RequestCounter()
        let session = ScreenshotCacheMockURLProtocol.makeSession { _ in
            requestCounter.increment()
            return (statusCode: 200, data: Self.samplePNG)
        }

        let cache = ScreenshotImageCache(
            rootDirectory: directory,
            session: session,
            diskStore: diskStore
        )

        let data = try await cache.data(for: url, screenshotID: "shot-a")
        #expect(data == Self.samplePNG)
        #expect(requestCounter.value == 0)
    }

    @Test("reuses memory for repeated requests")
    func memoryHitAvoidsNetwork() async throws {
        ScreenshotCacheMockURLProtocol.reset()
        defer { ScreenshotCacheMockURLProtocol.reset() }

        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = URL(string: "https://example.com/screenshot-b.png")!
        let requestCounter = RequestCounter()
        let session = ScreenshotCacheMockURLProtocol.makeSession { _ in
            requestCounter.increment()
            return (statusCode: 200, data: Self.samplePNG)
        }
        let cache = ScreenshotImageCache(rootDirectory: directory, session: session)

        _ = try await cache.data(for: url, screenshotID: "shot-b")
        _ = try await cache.data(for: url, screenshotID: "shot-b")

        #expect(requestCounter.value == 1)
    }

    @Test("deduplicates concurrent requests for the same URL")
    func deduplicatesInFlightRequests() async throws {
        ScreenshotCacheMockURLProtocol.reset()
        defer {
            ScreenshotCacheMockURLProtocol.reset()
        }

        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = URL(string: "https://example.com/screenshot-c.png")!
        let requestCounter = RequestCounter()
        let session = ScreenshotCacheMockURLProtocol.makeSession { _ in
            requestCounter.increment()
            Thread.sleep(forTimeInterval: 0.05)
            return (statusCode: 200, data: Self.samplePNG)
        }
        let cache = ScreenshotImageCache(rootDirectory: directory, session: session)

        try await withThrowingTaskGroup(of: Data.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    try await cache.data(for: url, screenshotID: "shot-c")
                }
            }
            var results: [Data] = []
            for try await data in group {
                results.append(data)
            }
            #expect(results.count == 10)
        }

        #expect(requestCounter.value == 1)
    }

    @Test("invalidates entries by screenshot ID")
    func invalidateByScreenshotID() async throws {
        let directory = makeTemporaryCacheDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            ScreenshotCacheMockURLProtocol.reset()
        }

        let url = URL(string: "https://example.com/screenshot-d.png")!
        let session = ScreenshotCacheMockURLProtocol.makeSession { _ in
            (statusCode: 200, data: Self.samplePNG)
        }
        let cache = ScreenshotImageCache(rootDirectory: directory, session: session)

        _ = try await cache.data(for: url, screenshotID: "shot-d")
        await cache.invalidate(screenshotID: "shot-d")

        let key = ScreenshotCacheDiskStore.cacheKey(for: url)
        let diskStore = ScreenshotCacheDiskStore(rootDirectory: directory)
        #expect(diskStore.readData(for: key) == nil)
        #expect(diskStore.diskUsage().fileCount == 0)
    }

    @Test("clears disk and memory cache")
    func clearRemovesAllEntries() async throws {
        let directory = makeTemporaryCacheDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            ScreenshotCacheMockURLProtocol.reset()
        }

        let url = URL(string: "https://example.com/screenshot-e.png")!
        let session = ScreenshotCacheMockURLProtocol.makeSession { _ in
            (statusCode: 200, data: Self.samplePNG)
        }
        let cache = ScreenshotImageCache(rootDirectory: directory, session: session)

        _ = try await cache.data(for: url, screenshotID: "shot-e")
        await cache.clear()

        let diskStore = ScreenshotCacheDiskStore(rootDirectory: directory)
        #expect(diskStore.diskUsage().fileCount == 0)
    }

    @Test("re-downloads when cached file is corrupted")
    func corruptDiskEntryTriggersNetworkRefresh() async throws {
        let directory = makeTemporaryCacheDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            ScreenshotCacheMockURLProtocol.reset()
        }

        let url = URL(string: "https://example.com/screenshot-f.png")!
        let key = ScreenshotCacheDiskStore.cacheKey(for: url)
        let diskStore = ScreenshotCacheDiskStore(rootDirectory: directory)
        #expect(diskStore.store(key: key, sourceURL: url, screenshotID: "shot-f", data: Data([0x00, 0x01, 0x02])))

        let requestCounter = RequestCounter()
        let session = ScreenshotCacheMockURLProtocol.makeSession { _ in
            requestCounter.increment()
            return (statusCode: 200, data: Self.samplePNG)
        }
        let cache = ScreenshotImageCache(
            rootDirectory: directory,
            session: session,
            diskStore: diskStore
        )

        let data = try await cache.data(for: url, screenshotID: "shot-f")
        #expect(data == Self.samplePNG)
        #expect(requestCounter.value == 1)
    }

    @Test("evicts least recently used disk entries when over capacity")
    func lruEvictionRemovesOldestEntry() {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let diskStore = ScreenshotCacheDiskStore(
            rootDirectory: directory,
            diskByteLimit: 80,
            diskTargetByteCount: 40
        )

        let urls = [
            URL(string: "https://example.com/one.png")!,
            URL(string: "https://example.com/two.png")!,
            URL(string: "https://example.com/three.png")!
        ]
        let chunk = Data(repeating: 0xAB, count: 30)
        let base = Date()

        for (index, url) in urls.enumerated() {
            let key = ScreenshotCacheDiskStore.cacheKey(for: url)
            #expect(
                diskStore.store(
                    key: key,
                    sourceURL: url,
                    screenshotID: "shot-\(index)",
                    data: chunk,
                    now: base.addingTimeInterval(TimeInterval(index))
                )
            )
        }

        let usage = diskStore.diskUsage()
        #expect(usage.fileCount == 1)
        #expect(usage.byteCount == 30)
        #expect(diskStore.readData(for: ScreenshotCacheDiskStore.cacheKey(for: urls[0])) == nil)
        #expect(diskStore.readData(for: ScreenshotCacheDiskStore.cacheKey(for: urls[1])) == nil)
        #expect(diskStore.readData(for: ScreenshotCacheDiskStore.cacheKey(for: urls[2])) == chunk)
    }

    private func makeTemporaryCacheDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotImageCacheTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private final class ScreenshotCacheMockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (statusCode: Int, data: Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?

    static func makeSession(handler: @escaping Handler) -> URLSession {
        lock.withLock {
            self.handler = handler
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScreenshotCacheMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func reset() {
        lock.withLock {
            handler = nil
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        lock.withLock { handler != nil }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.lock.withLock({ Self.handler }) else {
                throw URLError(.badServerResponse)
            }
            let payload = try handler(request)
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: payload.statusCode,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "image/png"]
                  ) else {
                throw URLError(.badURL)
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: payload.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
