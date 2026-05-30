import Testing
import Foundation
import CryptoKit
@testable import PluginAppStoreConnect

@Suite(.serialized)
struct PluginAppStoreConnectTests {
    @Test
    func pluginIdentityIsStable() {
        #expect(AppStoreConnectPlugin.id == "AppStoreConnect")
        #expect(AppStoreConnectPlugin.iconName == "bag")
    }

    @Test
    func imageAssetTemplateURLReplacesApplePlaceholders() {
        let asset = AppStoreImageAsset(
            templateURL: "https://is1-ssl.mzstatic.com/image/thumb/source/{w}x{h}bb.{f}"
        )

        #expect(asset.url(width: 64, height: 64)?.absoluteString == "https://is1-ssl.mzstatic.com/image/thumb/source/64x64bb.png")
    }

    @Test
    func ciProductDecodesAttributesAndAppRelationship() throws {
        let json = """
        {
          "id": "product-1",
          "type": "ciProducts",
          "attributes": {
            "name": "Lumi iOS",
            "productType": "APP",
            "bundleId": "com.coffic.lumi",
            "createdDate": "2026-05-01T10:20:30Z"
          },
          "relationships": {
            "app": {
              "data": {
                "type": "apps",
                "id": "app-1"
              }
            },
            "primaryApp": {
              "data": {
                "type": "apps",
                "id": "app-1"
              }
            }
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let product = try decoder.decode(CiProduct.self, from: json)

        #expect(product.id == "product-1")
        #expect(product.name == "Lumi iOS")
        #expect(product.productType == "APP")
        #expect(product.bundleID == "com.coffic.lumi")
        #expect(product.appID == "app-1")
        #expect(product.primaryAppID == "app-1")
        #expect(product.createdDate != nil)
    }

    @Test
    func ciWorkflowDecodesCommonFields() throws {
        let json = """
        {
          "id": "workflow-1",
          "type": "ciWorkflows",
          "attributes": {
            "name": "Release",
            "description": "Archive and test",
            "isEnabled": true,
            "clean": true,
            "containerFilePath": "Lumi.xcworkspace",
            "platformType": "IOS",
            "createdDate": "2026-05-01T10:20:30Z"
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let workflow = try decoder.decode(CiWorkflow.self, from: json)

        #expect(workflow.id == "workflow-1")
        #expect(workflow.name == "Release")
        #expect(workflow.description == "Archive and test")
        #expect(workflow.isEnabled)
        #expect(workflow.clean)
        #expect(workflow.containerFilePath == "Lumi.xcworkspace")
        #expect(workflow.platformType == "IOS")
    }

    @Test
    func ciBuildRunCreatePayloadIncludesWorkflowAndBranch() throws {
        let body = try AppStoreConnectClient.makeCiBuildRunCreateBody(
            workflowID: "workflow-1",
            branch: " main "
        )
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = try #require(object?["data"] as? [String: Any])
        let attributes = try #require(data["attributes"] as? [String: Any])
        let relationships = try #require(data["relationships"] as? [String: Any])
        let workflow = try #require(relationships["workflow"] as? [String: Any])
        let workflowData = try #require(workflow["data"] as? [String: Any])

        #expect(data["type"] as? String == "ciBuildRuns")
        #expect(attributes["sourceBranchOrTag"] as? String == "main")
        #expect(workflowData["type"] as? String == "ciWorkflows")
        #expect(workflowData["id"] as? String == "workflow-1")
    }

    @Test
    func ciWorkflowEnabledUpdatePayloadOnlyPatchesEnabledState() throws {
        let body = try AppStoreConnectClient.makeCiWorkflowEnabledUpdateBody(id: "workflow-1", isEnabled: false)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = try #require(object?["data"] as? [String: Any])
        let attributes = try #require(data["attributes"] as? [String: Any])

        #expect(data["id"] as? String == "workflow-1")
        #expect(data["type"] as? String == "ciWorkflows")
        #expect(attributes["isEnabled"] as? Bool == false)
        #expect(attributes.keys.count == 1)
    }

    @Test
    func ciWorkflowExportEncodesStableConfigurationShape() throws {
        let workflow = CiWorkflow(
            id: "workflow-1",
            name: "Release",
            description: "Archive and test",
            isEnabled: true,
            clean: true,
            containerFilePath: "Lumi.xcworkspace",
            platformType: "IOS"
        )
        let data = try JSONEncoder().encode(CiWorkflowExport(workflow: workflow))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(object?["id"] as? String == "workflow-1")
        #expect(object?["name"] as? String == "Release")
        #expect(object?["description"] as? String == "Archive and test")
        #expect(object?["isEnabled"] as? Bool == true)
        #expect(object?["clean"] as? Bool == true)
        #expect(object?["containerFilePath"] as? String == "Lumi.xcworkspace")
        #expect(object?["platformType"] as? String == "IOS")
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(AppStoreConnectLocalization.bundle.url(forResource: "AppStoreConnect", withExtension: "xcstrings") != nil)
        #expect(AppStoreConnectLocalization.string("App Store").isEmpty == false)
    }

    @Test("plugin description resolves from package localization catalog")
    func pluginDescriptionUsesRequestedLanguage() {
        #expect(AppStoreConnectPlugin.description(for: .english) == "Manage App Store Connect apps, metadata, and screenshots")
        #expect(AppStoreConnectPlugin.description(for: .chinese) == "管理 App Store Connect App、元数据和截图")
    }

    @Test
    func credentialsRequireAllTrimmedFields() {
        #expect(AppStoreConnectCredentials(
            issuerID: " issuer ",
            keyID: " key ",
            privateKey: " private "
        ).isComplete)

        #expect(!AppStoreConnectCredentials(
            issuerID: "issuer",
            keyID: " ",
            privateKey: "private"
        ).isComplete)
    }

    @Test
    func ciBuildRunCreatePayloadOmitsEmptyBranch() throws {
        let body = try AppStoreConnectClient.makeCiBuildRunCreateBody(
            workflowID: "workflow-1",
            branch: "   "
        )
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = try #require(object?["data"] as? [String: Any])

        #expect(data["attributes"] == nil)
    }

    @Test
    func listAppsBuildsExpectedRequestAndMapsIncludedIcon() async throws {
        let session = MockURLProtocol.makeSession { request in
            #expect(request.url?.path == "/v1/apps")
            #expect(request.url?.query?.contains("limit=5") == true)
            #expect(request.url?.query?.contains("sort=name") == true)
            #expect(request.url?.query?.contains("filter%5Bname%5D=Lumi") == true)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true)

            return (
                200,
                """
                {
                  "data": [{
                    "id": "app-1",
                    "type": "apps",
                    "attributes": {
                      "name": "Lumi",
                      "bundleId": "com.coffic.lumi",
                      "sku": "LUMI",
                      "primaryLocale": "en-US",
                      "platform": "IOS"
                    },
                    "relationships": {
                      "appStoreIcon": {
                        "data": { "type": "buildIcons", "id": "icon-1" }
                      }
                    }
                  }],
                  "included": [{
                    "id": "icon-1",
                    "type": "buildIcons",
                    "attributes": {
                      "iconAsset": {
                        "templateUrl": "https://example.com/{w}x{h}.{f}"
                      }
                    }
                  }]
                }
                """.data(using: .utf8)!
            )
        }
        let client = AppStoreConnectClient(
            credentialsProvider: { Self.validCredentials() },
            session: session
        )

        let apps = try await client.listApps(search: "Lumi", limit: 5)

        #expect(apps.count == 1)
        #expect(apps.first?.name == "Lumi")
        #expect(apps.first?.iconURL?.absoluteString == "https://example.com/64x64.png")
    }

    @Test
    func clientRejectsMissingCredentialsBeforeSendingRequest() async throws {
        let session = MockURLProtocol.makeSession { _ in
            Issue.record("Request should not be sent when credentials are incomplete")
            return (200, #"{"data":[]}"#.data(using: .utf8)!)
        }
        let client = AppStoreConnectClient(
            credentialsProvider: {
                AppStoreConnectCredentials(issuerID: "", keyID: "key", privateKey: "private")
            },
            session: session
        )

        do {
            _ = try await client.listApps()
            Issue.record("Expected missing credentials error")
        } catch AppStoreConnectClientError.missingCredentials {
        } catch {
            Issue.record("Expected missing credentials error, got \(error)")
        }
    }

    @Test
    func clientUsesFirstAppStoreConnectErrorMessage() async throws {
        let session = MockURLProtocol.makeSession { _ in
            (
                401,
                """
                {
                  "errors": [{
                    "status": "401",
                    "code": "NOT_AUTHORIZED",
                    "title": "Unauthorized",
                    "detail": "Invalid token"
                  }]
                }
                """.data(using: .utf8)!
            )
        }
        let client = AppStoreConnectClient(
            credentialsProvider: { Self.validCredentials() },
            session: session
        )

        do {
            _ = try await client.listApps()
            Issue.record("Expected request failed error")
        } catch AppStoreConnectClientError.requestFailed(let message) {
            #expect(message == "Unauthorized: Invalid token")
        } catch {
            Issue.record("Expected request failed error, got \(error)")
        }
    }

    private static func validCredentials() -> AppStoreConnectCredentials {
        AppStoreConnectCredentials(
            issuerID: UUID().uuidString,
            keyID: "ABC123DEFG",
            privateKey: P256.Signing.PrivateKey().pemRepresentation
        )
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (statusCode: Int, data: Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?

    static func makeSession(handler: @escaping Handler) -> URLSession {
        lock.withLock {
            self.handler = handler
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.lock.withLock({ Self.handler }) else {
                throw URLError(.badServerResponse)
            }
            let responsePayload = try handler(request)
            guard let url = request.url,
                  let response = HTTPURLResponse(
                url: url,
                statusCode: responsePayload.statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ) else {
                throw URLError(.badURL)
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: responsePayload.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
