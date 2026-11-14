import CryptoKit
import Foundation
import KitTestSupport
import ProviderNetwork
import Testing
@testable import PluginAppStoreConnect

/// App Store Connect 一次请求可能返回多个顶层错误。
///
/// 此前 `apiErrorMessage` 只读取 `errors.first`，除首个外的失败原因会被
/// 静默丢弃，用户看不到完整的修复项（#322）。这些用例通过 stub 网络驱动
/// 真实的 `requestWithoutResponse` → `apiError` → `apiErrorMessage` 链路。
@Suite("ConnectClient 错误文案聚合")
struct ConnectClientErrorFormattingTests {

    @Test("多个顶层错误的 title/detail 全部透出")
    func multipleTopLevelErrorsAreAllSurfaced() async throws {
        let directory = try TemporaryDirectory.make("asc-client-errors")
        defer { directory.remove() }
        let body = Data("""
        {"errors":[\
        {"status":"400","code":"ENTITY_ERROR.ATTRIBUTE.INVALID","title":"Invalid attribute","detail":"The bundle ID is already in use."},\
        {"status":"400","code":"ENTITY_ERROR.RELATIONSHIP.INVALID","title":"Invalid relationship","detail":"The build is not valid for this version."}\
        ]}
        """.utf8)
        let client = makeClient(statusCode: 400, body: body, directory: directory)

        let message = try await errorMessage(from: client)

        #expect(message.contains("Invalid attribute"))
        #expect(message.contains("The bundle ID is already in use."))
        #expect(message.contains("Invalid relationship"))
        #expect(message.contains("The build is not valid for this version."))
    }

    @Test("单个错误的文案格式保持不变")
    func singleErrorFormatIsUnchanged() async throws {
        let directory = try TemporaryDirectory.make("asc-client-errors")
        defer { directory.remove() }
        let body = Data("""
        {"errors":[{"status":"409","code":"ENTITY_ERROR.ATTRIBUTE.INVALID",\
        "title":"The provided entity includes an attribute with an invalid value",\
        "detail":"You cannot update when the value is already set."}]}
        """.utf8)
        let client = makeClient(statusCode: 409, body: body, directory: directory)

        let message = try await errorMessage(from: client)

        #expect(message == "The provided entity includes an attribute with an invalid value: You cannot update when the value is already set.")
    }

    @Test("多个顶层错误各自的关联明细都透出")
    func associatedErrorsFromAllTopLevelErrorsAreSurfaced() async throws {
        let directory = try TemporaryDirectory.make("asc-client-errors")
        defer { directory.remove() }
        let body = Data("""
        {"errors":[\
        {"status":"409","code":"STATE_ERROR","title":"Submission problem","detail":"The submission is incomplete.",\
        "meta":{"associatedErrors":{"reviewContact":[{"detail":"Review contact first name is required."}]}}},\
        {"status":"409","code":"STATE_ERROR","title":"Build problem","detail":"The build cannot be submitted.",\
        "meta":{"associatedErrors":{"build":[{"detail":"The build is still processing."}]}}}\
        ]}
        """.utf8)
        let client = makeClient(statusCode: 409, body: body, directory: directory)

        let message = try await errorMessage(from: client)

        #expect(message.contains("The submission is incomplete."))
        #expect(message.contains("Review contact first name is required."))
        #expect(message.contains("The build cannot be submitted."))
        #expect(message.contains("The build is still processing."))
    }

    @Test("空错误数组回退到 HTTP 文案")
    func emptyErrorsArrayFallsBackToHTTPMessage() async throws {
        let directory = try TemporaryDirectory.make("asc-client-errors")
        defer { directory.remove() }
        let body = Data(#"{"errors":[]}"#.utf8)
        let client = makeClient(statusCode: 500, body: body, directory: directory)

        let message = try await errorMessage(from: client)

        #expect(message.contains("500"))
    }

    // MARK: - Helpers

    /// 驱动一次必然失败的请求，捕获服务端错误文案。
    private func errorMessage(from client: ConnectClient) async throws -> String {
        do {
            try await client.requestWithoutResponse(path: "/v1/appStoreVersions", method: "POST")
            Issue.record("Expected the request to throw an App Store Connect error")
            return ""
        } catch let error as AppStoreConnectClientError {
            return error.errorDescription ?? ""
        }
    }

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