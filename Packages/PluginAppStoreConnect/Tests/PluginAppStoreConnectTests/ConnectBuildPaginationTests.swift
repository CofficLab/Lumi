import CryptoKit
import Foundation
import KitTestSupport
import ProviderNetwork
import Testing
@testable import PluginAppStoreConnect

/// 回归 #818：Builds 查询此前只请求首页 limit=50，不跟随 `links.next`，
/// 第 51 个之后的构建对 UI 与 Agent 完全不可见。现在翻页合并全部结果。
@Suite("ConnectClient Builds 分页")
struct ConnectBuildPaginationTests {

    @Test("follows links.next and merges all pages")
    func followsNextLinksAndMergesAllPages() async throws {
        let directory = try TemporaryDirectory.make("asc-builds-pagination")
        defer { directory.remove() }

        let page1 = makeDocument(
            builds: [
                makeBuild(id: "b1", version: "1", state: "VALID", versionResourceID: "v1"),
                makeBuild(id: "b2", version: "2", state: "VALID", versionResourceID: "v1"),
            ],
            includedVersions: [makePreReleaseVersion(id: "v1", version: "2.1.0")],
            next: "https://api.appstoreconnect.apple.com/v1/builds?cursor=abc"
        )
        let page2 = makeDocument(
            builds: [
                makeBuild(id: "b3", version: "3", state: "VALID", versionResourceID: "v2"),
            ],
            includedVersions: [makePreReleaseVersion(id: "v2", version: "2.0.0")],
            next: nil
        )
        let network = PagedStubNetwork(bodies: [page1, page2])
        let client = makeClient(network: network, directory: directory)

        let builds = try await client.listBuilds(appID: "app-1")

        #expect(network.requestCount == 2)
        #expect(builds.map(\.id) == ["b1", "b2", "b3"])
        #expect(builds[0].displayLabel == "2.1.0 (1)")
        #expect(builds[2].displayLabel == "2.0.0 (3)")
    }

    @Test("single page without next link stops after one request")
    func singlePageStopsWithoutNextLink() async throws {
        let directory = try TemporaryDirectory.make("asc-builds-single")
        defer { directory.remove() }

        let page1 = makeDocument(
            builds: [
                makeBuild(id: "b1", version: "1", state: "VALID", versionResourceID: nil),
            ],
            includedVersions: [],
            next: nil
        )
        let network = PagedStubNetwork(bodies: [page1])
        let client = makeClient(network: network, directory: directory)

        let builds = try await client.listBuilds(appID: "app-1")

        #expect(network.requestCount == 1)
        #expect(builds.count == 1)
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

    private func makeBuild(id: String, version: String, state: String, versionResourceID: String?) -> String {
        if let versionResourceID {
            let relationship = #"{"type":"preReleaseVersions","id":"\#(versionResourceID)"}"#
            return """
            {"type":"builds","id":"\(id)","attributes":{"version":"\(version)","processingState":"\(state)","expired":false},"relationships":{"preReleaseVersion":{"data":\(relationship)}}}
            """
        }
        return """
        {"type":"builds","id":"\(id)","attributes":{"version":"\(version)","processingState":"\(state)","expired":false}}
        """
    }

    private func makePreReleaseVersion(id: String, version: String) -> String {
        #"{"type":"preReleaseVersions","id":"\#(id)","attributes":{"version":"\#(version)","platform":"MAC_OS"}}"#
    }

    private func makeDocument(builds: [String], includedVersions: [String], next: String?) -> Data {
        let linksPart: String
        if let next {
            linksPart = #","links":{"next":"\#(next)"}"#
        } else {
            linksPart = ""
        }
        let includedPart: String
        if includedVersions.isEmpty {
            includedPart = ""
        } else {
            includedPart = #","included":[\#(includedVersions.joined(separator: ","))]"#
        }
        let json = """
        {"data":[\(builds.joined(separator: ","))]\(includedPart)\(linksPart)}
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
