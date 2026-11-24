import CryptoKit
import Foundation
import KitTestSupport
import ProviderNetwork
import Testing
@testable import PluginAppStoreConnect

/// 回归覆盖 issue #319：`/v1/apps` 与版本列表此前固定 limit=100 单页请求，
/// 且列表响应模型不保留 `links.next`，第二页之后的数据对 UI 与 Agent
/// 完全不可见且无任何截断提示。现在跟随 `links.next` 合并全部页。
@Suite("ConnectClient Apps/Versions 分页")
struct ConnectListPaginationTests {

    @Test("listApps follows links.next and merges all pages")
    func listAppsFollowsNextLinksAndMergesAllPages() async throws {
        let directory = try TemporaryDirectory.make("asc-apps-pagination")
        defer { directory.remove() }

        let page1 = makeAppsDocument(
            apps: [makeApp(id: "a1"), makeApp(id: "a2")],
            next: "https://api.appstoreconnect.apple.com/v1/apps?cursor=p1"
        )
        let page2 = makeAppsDocument(
            apps: [makeApp(id: "a3")],
            next: nil
        )
        let network = PagedStubNetwork(bodies: [page1, page2])
        let client = makeClient(network: network, directory: directory)

        let apps = try await client.listApps()

        #expect(network.requestCount == 2)
        #expect(apps.map(\.id) == ["a1", "a2", "a3"])
    }

    @Test("listApps with followPagination false stops after one request")
    func listAppsBoundedQueryStaysSinglePage() async throws {
        let directory = try TemporaryDirectory.make("asc-apps-bounded")
        defer { directory.remove() }

        let page1 = makeAppsDocument(
            apps: [makeApp(id: "a1")],
            next: "https://api.appstoreconnect.apple.com/v1/apps?cursor=p1"
        )
        let network = PagedStubNetwork(bodies: [page1])
        let client = makeClient(network: network, directory: directory)

        let apps = try await client.listApps(limit: 1, followPagination: false)

        #expect(network.requestCount == 1)
        #expect(apps.map(\.id) == ["a1"])
    }

    @Test("listVersions follows links.next and merges all pages")
    func listVersionsFollowsNextLinksAndMergesAllPages() async throws {
        let directory = try TemporaryDirectory.make("asc-versions-pagination")
        defer { directory.remove() }

        let page1 = makeVersionsDocument(
            versions: [
                makeVersion(id: "v1", versionString: "1.0", createdDate: "2024-03-01T00:00:00Z"),
                makeVersion(id: "v2", versionString: "1.1", createdDate: "2024-04-01T00:00:00Z"),
            ],
            next: "https://api.appstoreconnect.apple.com/v1/apps/app-1/appStoreVersions?cursor=p1"
        )
        let page2 = makeVersionsDocument(
            versions: [
                makeVersion(id: "v3", versionString: "1.2", createdDate: "2024-05-01T00:00:00Z"),
            ],
            next: nil
        )
        let network = PagedStubNetwork(bodies: [page1, page2])
        let client = makeClient(network: network, directory: directory)

        let versions = try await client.listVersions(appID: "app-1")

        // 结果按 createdDate 倒序：第二页的 v3 最新，排在最前。
        #expect(network.requestCount == 2)
        #expect(versions.map(\.id) == ["v3", "v2", "v1"])
    }

    // MARK: - Helpers

    private func makeClient(network: PagedStubNetwork, directory: TemporaryDirectory) -> ConnectClient {
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

    private func makeApp(id: String) -> String {
        """
        {"type":"apps","id":"\(id)","attributes":{"name":"App \(id)","bundleId":"com.example.\(id)","sku":"SKU-\(id)","primaryLocale":"en-US","platform":"IOS"}}
        """
    }

    private func makeAppsDocument(apps: [String], next: String?) -> Data {
        makeDocument(resources: apps, next: next)
    }

    private func makeVersion(id: String, versionString: String, createdDate: String) -> String {
        """
        {"type":"appStoreVersions","id":"\(id)","attributes":{"platform":"IOS","versionString":"\(versionString)","appStoreState":"READY_FOR_SALE","appVersionState":"ACCEPTED","createdDate":"\(createdDate)"}}
        """
    }

    private func makeVersionsDocument(versions: [String], next: String?) -> Data {
        makeDocument(resources: versions, next: next)
    }

    private func makeDocument(resources: [String], next: String?) -> Data {
        let linksPart: String
        if let next {
            linksPart = #","links":{"next":"\#(next)"}"#
        } else {
            linksPart = ""
        }
        let json = """
        {"data":[\(resources.joined(separator: ","))]\(linksPart)}
        """
        return Data(json.utf8)
    }
}

/// 按请求顺序返回预设响应的网络替身，并统计请求次数。
private final class PagedStubNetwork: NetworkProviding, @unchecked Sendable {
    private let bodies: [Data]
    private(set) var requestCount = 0

    init(bodies: [Data]) {
        self.bodies = bodies
    }

    func request(_ request: HTTPRequest) async throws -> HTTPResponse {
        let index = min(requestCount, bodies.count - 1)
        requestCount += 1
        return HTTPResponse(
            statusCode: 200,
            headers: [:],
            body: bodies[index],
            url: request.url
        )
    }

    func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {}
}
