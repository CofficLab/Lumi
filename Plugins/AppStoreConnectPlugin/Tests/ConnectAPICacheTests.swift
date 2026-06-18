import CryptoKit
import Foundation
import Testing
@testable import AppStoreConnectPlugin

@Suite("Connect API cache", .serialized)
struct ConnectAPICacheTests {
    private static let sampleAppsJSON = """
    {
      "data": [{
        "id": "app-1",
        "type": "apps",
        "attributes": {
          "name": "Lumi",
          "bundleId": "com.coffic.lumi",
          "sku": "LUMI",
          "primaryLocale": "en-US"
        }
      }]
    }
    """.data(using: .utf8)!

    private static let sampleVersionsJSON = """
    {
      "data": [{
        "id": "version-released",
        "type": "appStoreVersions",
        "attributes": {
          "platform": "IOS",
          "versionString": "1.0.0",
          "appStoreState": "READY_FOR_SALE",
          "appVersionState": "READY_FOR_SALE"
        }
      }]
    }
    """.data(using: .utf8)!

    @Test("reads from disk without using memory")
    func diskHitPopulatesMemory() {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let logicalKey = "issuer|key|GET|/v1/apps|limit=1"
        let diskStore = ConnectAPICacheDiskStore(rootDirectory: directory)
        #expect(
            diskStore.store(
                logicalKey: logicalKey,
                method: "GET",
                path: "/v1/apps",
                retention: .standard,
                tags: [],
                data: Self.sampleAppsJSON
            )
        )

        let memory = ConnectCache(ttl: 60, maxEntries: 8)
        let cache = ConnectAPICache(rootDirectory: directory, memoryCache: memory, diskStore: diskStore)

        let data = cache.get(logicalKey: logicalKey, fetchPolicy: .cacheFirst)
        #expect(data == Self.sampleAppsJSON)
        #expect(cache.get(logicalKey: logicalKey, fetchPolicy: .cacheFirst) == Self.sampleAppsJSON)
    }

    @Test("standard retention expires on disk")
    func standardRetentionExpires() {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let logicalKey = "issuer|key|GET|/v1/apps|"
        let diskStore = ConnectAPICacheDiskStore(rootDirectory: directory)
        let stale = Date().addingTimeInterval(-ConnectAPICacheConfiguration.standardTTL - 10)
        #expect(
            diskStore.store(
                logicalKey: logicalKey,
                method: "GET",
                path: "/v1/apps",
                retention: .standard,
                tags: [],
                data: Self.sampleAppsJSON,
                now: stale
            )
        )

        let cache = ConnectAPICache(rootDirectory: directory, diskStore: diskStore)
        #expect(cache.get(logicalKey: logicalKey, fetchPolicy: .cacheFirst) == nil)
    }

    @Test("immutable retention does not expire")
    func immutableRetentionPersists() {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let logicalKey = "issuer|key|GET|/v1/appStoreVersions/v1/appStoreVersionLocalizations|"
        let diskStore = ConnectAPICacheDiskStore(rootDirectory: directory)
        let stale = Date().addingTimeInterval(-ConnectAPICacheConfiguration.standardTTL * 48)
        #expect(
            diskStore.store(
                logicalKey: logicalKey,
                method: "GET",
                path: "/v1/appStoreVersions/v1/appStoreVersionLocalizations",
                retention: .immutable,
                tags: [.version("v1")],
                data: Self.sampleAppsJSON,
                now: stale
            )
        )

        let cache = ConnectAPICache(rootDirectory: directory, diskStore: diskStore)
        #expect(cache.get(logicalKey: logicalKey, fetchPolicy: .cacheFirst) == Self.sampleAppsJSON)
    }

    @Test("version state index assigns immutable retention for released versions")
    func versionStateIndexDrivesImmutablePolicy() {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let indexesDirectory = directory.appendingPathComponent(
            ConnectAPICacheConfiguration.indexesDirectoryName,
            isDirectory: true
        )
        let index = VersionStateIndex(indexesDirectory: indexesDirectory)
        index.update(fromVersionsListResponse: Self.sampleVersionsJSON, appID: "app-1")

        let policy = ConnectCachePolicyResolver.resolve(
            method: "GET",
            path: "/v1/appStoreVersions/version-released/appStoreVersionLocalizations",
            versionStateIndex: index
        )
        #expect(policy.retention == .immutable)
        #expect(policy.tags.contains(.version("version-released")))
    }

    @Test("mutation invalidation removes scoped entries only")
    func mutationInvalidatesLocalizationScope() {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let accountKey = "issuer|key"
        let localizationKey = "\(accountKey)|GET|/v1/appStoreVersionLocalizations/loc-1|"
        let appsKey = "\(accountKey)|GET|/v1/apps|limit=1"
        let cache = ConnectAPICache(rootDirectory: directory)

        cache.set(
            logicalKey: localizationKey,
            method: "GET",
            path: "/v1/appStoreVersionLocalizations/loc-1",
            data: Self.sampleAppsJSON
        )
        cache.set(
            logicalKey: appsKey,
            method: "GET",
            path: "/v1/apps",
            data: Self.sampleAppsJSON
        )

        cache.invalidateAfterMutation(
            method: "PATCH",
            path: "/v1/appStoreVersionLocalizations/loc-1",
            body: nil,
            accountKey: accountKey
        )

        #expect(cache.get(logicalKey: localizationKey, fetchPolicy: .cacheFirst) == nil)
        #expect(cache.get(logicalKey: appsKey, fetchPolicy: .cacheFirst) == Self.sampleAppsJSON)
    }

    @Test("clear removes disk and index state")
    func clearRemovesAllPersistedData() {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = ConnectAPICache(rootDirectory: directory)
        cache.set(
            logicalKey: "issuer|key|GET|/v1/apps|",
            method: "GET",
            path: "/v1/apps",
            data: Self.sampleAppsJSON
        )
        cache.clear()

        let diskStore = ConnectAPICacheDiskStore(rootDirectory: directory)
        #expect(diskStore.diskUsage().fileCount == 0)
    }

    @Test("evicts least recently used disk entries when over capacity")
    func lruEvictionRemovesOldestEntry() {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let diskStore = ConnectAPICacheDiskStore(
            rootDirectory: directory,
            diskByteLimit: 80,
            diskTargetByteCount: 40
        )

        let keys = ["one", "two", "three"]
        let chunk = Data(repeating: 0xAB, count: 30)
        let base = Date()

        for (index, key) in keys.enumerated() {
            #expect(
                diskStore.store(
                    logicalKey: key,
                    method: "GET",
                    path: "/v1/apps",
                    retention: .standard,
                    tags: [],
                    data: chunk,
                    now: base.addingTimeInterval(TimeInterval(index))
                )
            )
        }

        let usage = diskStore.diskUsage()
        #expect(usage.fileCount == 1)
        #expect(usage.byteCount == 30)
        #expect(diskStore.read(logicalKey: "one") == nil)
        #expect(diskStore.read(logicalKey: "two") == nil)
        #expect(diskStore.read(logicalKey: "three")?.data == chunk)
    }

    @Test("reconcile removes orphan object files")
    func reconcileRemovesOrphans() {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let diskStore = ConnectAPICacheDiskStore(rootDirectory: directory)
        let orphanURL = diskStore.objectURL(for: "orphan-object")
        try? Data([0x01]).write(to: orphanURL)

        let reconciled = ConnectAPICacheDiskStore(rootDirectory: directory)
        #expect(reconciled.diskUsage().fileCount == 0)
        #expect(FileManager.default.fileExists(atPath: orphanURL.path) == false)
    }

    @Test("client reuses disk cache across memory eviction")
    func clientReusesDiskCache() async throws {
        let directory = makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        final class RequestCounter: @unchecked Sendable {
            var count = 0
        }
        let counter = RequestCounter()
        let session = ConnectAPICacheMockURLProtocol.makeSession { _ in
            counter.count += 1
            return (statusCode: 200, data: Self.sampleAppsJSON)
        }

        let memory = ConnectCache(ttl: 60, maxEntries: 8)
        let cache = ConnectAPICache(rootDirectory: directory, memoryCache: memory)
        let credentials = AppStoreConnectCredentials(
            issuerID: "issuer-test",
            keyID: "ABC123DEFG",
            privateKey: P256.Signing.PrivateKey().pemRepresentation
        )
        let client = ConnectClient(
            credentialsProvider: { credentials },
            session: session,
            cache: cache
        )

        _ = try await client.listApps(limit: 1)
        memory.clear()
        _ = try await client.listApps(limit: 1)

        #expect(counter.count == 1)
    }

    private func makeTemporaryCacheDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConnectAPICacheTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private final class ConnectAPICacheMockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (statusCode: Int, data: Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?

    static func makeSession(handler: @escaping Handler) -> URLSession {
        lock.withLock { self.handler = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ConnectAPICacheMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func reset() {
        lock.withLock { handler = nil }
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
                    headerFields: ["Content-Type": "application/json"]
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
