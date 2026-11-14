import CryptoKit
import Foundation
import KitTestSupport
import ProviderNetwork
import Testing
@testable import PluginAppStoreConnect

/// 回归 #320：forceRefresh 必须让 ConnectClient 以 networkOnly 策略请求，
/// 绕过未过期的 GET 缓存；默认调用仍沿用 cacheFirst 复用缓存。
@Suite("ConnectClient 刷新绕过缓存")
struct ConnectClientRefreshCacheTests {

    @Test("forceRefresh 绕过版本列表缓存，重新走网络")
    func forceRefreshBypassesVersionListCache() async throws {
        let directory = try TemporaryDirectory.make("asc-refresh-cache")
        defer { directory.remove() }
        let bodyA = Data(#"{"data":[{"id":"v1","attributes":{"versionString":"1.0.0"}}]}"#.utf8)
        let bodyB = Data(#"{"data":[{"id":"v1","attributes":{"versionString":"2.0.0"}}]}"#.utf8)
        let network = CountingNetwork(bodies: [bodyA, bodyB])
        let client = makeClient(network: network, directory: directory)

        let first = try await client.listVersions(appID: "app-1")
        #expect(first.map(\.versionString) == ["1.0.0"])
        #expect(network.callCount == 1)

        let cached = try await client.listVersions(appID: "app-1")
        #expect(cached.map(\.versionString) == ["1.0.0"])
        #expect(network.callCount == 1)

        let refreshed = try await client.listVersions(appID: "app-1", forceRefresh: true)
        #expect(refreshed.map(\.versionString) == ["2.0.0"])
        #expect(network.callCount == 2)
    }

    @Test("默认版本列表请求复用未过期缓存")
    func defaultVersionListReusesCache() async throws {
        let directory = try TemporaryDirectory.make("asc-refresh-cache")
        defer { directory.remove() }
        let body = Data(#"{"data":[{"id":"v1","attributes":{"versionString":"1.0.0"}}]}"#.utf8)
        let network = CountingNetwork(bodies: [body])
        let client = makeClient(network: network, directory: directory)

        _ = try await client.listVersions(appID: "app-1")
        let second = try await client.listVersions(appID: "app-1")
        #expect(second.map(\.versionString) == ["1.0.0"])
        #expect(network.callCount == 1)
    }

    @Test("forceRefresh 绕过 App 读取缓存，重新走网络")
    func forceRefreshBypassesAppReadCache() async throws {
        let directory = try TemporaryDirectory.make("asc-refresh-cache")
        defer { directory.remove() }
        let bodyA = Data(#"{"data":{"id":"app-1","attributes":{"name":"Old"}}}"#.utf8)
        let bodyB = Data(#"{"data":{"id":"app-1","attributes":{"name":"New"}}}"#.utf8)
        let network = CountingNetwork(bodies: [bodyA, bodyB])
        let client = makeClient(network: network, directory: directory)

        let first = try await client.readApp(id: "app-1")
        #expect(first.name == "Old")
        #expect(network.callCount == 1)

        let cached = try await client.readApp(id: "app-1")
        #expect(cached.name == "Old")
        #expect(network.callCount == 1)

        let refreshed = try await client.readApp(id: "app-1", forceRefresh: true)
        #expect(refreshed.name == "New")
        #expect(network.callCount == 2)
    }

    // MARK: - Helpers

    private func makeClient(network: CountingNetwork, directory: TemporaryDirectory) -> ConnectClient {
        let credentials = AppStoreConnectCredentials(
            issuerID: "issuer-id",
            keyID: "key-id",
            privateKey: P256.Signing.PrivateKey().pemRepresentation
        )
        return ConnectClient(
            credentialsProvider: { credentials },
            network: network,
            cache: ConnectAPICache(rootDirectory: directory.url)
        )
    }
}

/// 按调用次序返回预设响应体并统计请求数的网络替身。
private final class CountingNetwork: NetworkProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let bodies: [Data]
    private var count = 0

    init(bodies: [Data]) {
        self.bodies = bodies
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    private func nextIndex() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let index = count
        count += 1
        return index
    }

    func request(_ request: HTTPRequest) async throws -> HTTPResponse {
        let index = nextIndex()
        let body = bodies[min(index, bodies.count - 1)]
        return HTTPResponse(statusCode: 200, headers: [:], body: body, url: request.url)
    }

    func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {}
}