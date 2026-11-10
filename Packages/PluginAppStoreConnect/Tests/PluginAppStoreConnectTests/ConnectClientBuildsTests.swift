import CryptoKit
import Foundation
import KitTestSupport
import ProviderNetwork
import Testing
@testable import PluginAppStoreConnect

/// 关联 build 时附带的出口合规声明不能把主操作搞失败。
///
/// Apple 在 `usesNonExemptEncryption` 已经是目标值时返回 409
/// `ENTITY_ERROR.ATTRIBUTE.INVALID`。此前这个错误会直接中止整个
/// `assign_build` 调用，build 最终没有被关联。
@Suite("ConnectClient 构建出口合规声明")
struct ConnectClientBuildsTests {

    private static let alreadySetBody = Data("""
    {"errors":[{"status":"409","code":"ENTITY_ERROR.ATTRIBUTE.INVALID",\
    "title":"The provided entity includes an attribute with an invalid value",\
    "detail":"You cannot update when the value is already set."}]}
    """.utf8)

    @Test("声明值已相同时视为已达成，不抛错")
    func alreadySetDeclarationIsTreatedAsNoop() async throws {
        let directory = try TemporaryDirectory.make("asc-client-builds")
        defer { directory.remove() }
        let client = makeClient(statusCode: 409, body: Self.alreadySetBody, directory: directory)

        let changed = try await client.updateBuildEncryption(
            buildID: "build-1",
            usesNonExemptEncryption: false
        )

        #expect(changed == false)
    }

    @Test("其它失败仍然抛出")
    func otherFailuresStillThrow() async throws {
        let directory = try TemporaryDirectory.make("asc-client-builds")
        defer { directory.remove() }
        let body = Data(#"{"errors":[{"status":"500","code":"UNKNOWN","title":"Server error"}]}"#.utf8)
        let client = makeClient(statusCode: 500, body: body, directory: directory)

        await #expect(throws: AppStoreConnectClientError.self) {
            _ = try await client.updateBuildEncryption(
                buildID: "build-1",
                usesNonExemptEncryption: false
            )
        }
    }

    // MARK: - Helpers

    private func makeClient(
        statusCode: Int,
        body: Data,
        directory: TemporaryDirectory
    ) -> ConnectClient {
        let credentials = AppStoreConnectCredentials(
            issuerID: "issuer-id",
            keyID: "key-id",
            privateKey: P256.Signing.PrivateKey().pemRepresentation
        )
        return ConnectClient(
            credentialsProvider: { credentials },
            network: StubNetwork(statusCode: statusCode, body: body),
            cache: ConnectAPICache(rootDirectory: directory.url)
        )
    }
}

/// 固定返回一份响应的网络替身。
private final class StubNetwork: NetworkProviding, @unchecked Sendable {
    private let statusCode: Int
    private let body: Data

    init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func request(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(
            statusCode: statusCode,
            headers: [:],
            body: body,
            url: request.url
        )
    }

    func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {}
}
