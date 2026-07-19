import Testing
import Foundation
import CryptoKit
import LumiCoreKit
@testable import AppStoreConnectPlugin

@Suite(.serialized)
struct PluginAppStoreConnectTests {
    @Test
    func pluginIdentityIsStable() {
        #expect(AppStoreConnectPlugin.id == "com.coffic.lumi.plugin.app-store-connect")
        #expect(AppStoreConnectPlugin.iconName == "bag")
        #expect(AppStoreConnectPlugin.policy == .optIn)
        #expect(AppStoreConnectPlugin.order == 65)
        #expect(AppStoreConnectPlugin.category == .development)
    }

    @MainActor
    @Test
    func titleToolbarItemsShowAppPickerOnlyInAppStoreSection() {
        let hidden = AppStoreConnectPlugin.titleToolbarItems(
            lumiCore: LumiPluginContext(activeSectionID: "editor", activeSectionTitle: "Editor")
        )
        let visible = AppStoreConnectPlugin.titleToolbarItems(
            lumiCore: LumiPluginContext(
                activeSectionID: AppStoreConnectPlugin.id,
                activeSectionTitle: AppStoreConnectPlugin.displayName
            )
        )

        #expect(hidden.isEmpty)
        #expect(visible.count == 1)
        #expect(visible.first?.id == "\(AppStoreConnectPlugin.id).app-picker")
        #expect(visible.first?.placement == .center)
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
        let body = try ConnectClient.makeCiBuildRunCreateBody(
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
        let body = try ConnectClient.makeCiWorkflowEnabledUpdateBody(id: "workflow-1", isEnabled: false)
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
        #expect(AppStoreConnectLocalization.bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(AppStoreConnectLocalization.string("App Store").isEmpty == false)
    }

    @Test("plugin description is localized")
    func pluginDescriptionUsesLocalizationCatalog() {
        #expect(AppStoreConnectPlugin.description.isEmpty == false)
        #expect(AppStoreConnectPlugin.displayName == "App Store")
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
        let body = try ConnectClient.makeCiBuildRunCreateBody(
            workflowID: "workflow-1",
            branch: "   "
        )
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = try #require(object?["data"] as? [String: Any])

        #expect(data["attributes"] == nil)
    }

    @Test
    func appScreenshotDecodesImageAsset() throws {
        let json = """
        {
          "id": "shot-1",
          "type": "appScreenshots",
          "attributes": {
            "fileName": "screenshot-1.png",
            "fileSize": 1024,
            "imageAsset": {
              "templateUrl": "https://example.com/{w}x{h}.{f}",
              "width": 1284,
              "height": 2778
            }
          }
        }
        """.data(using: .utf8)!

        let screenshot = try JSONDecoder().decode(AppScreenshot.self, from: json)

        #expect(screenshot.id == "shot-1")
        #expect(screenshot.fileName == "screenshot-1.png")
        #expect(screenshot.fileSize == 1024)
        #expect(screenshot.previewURL?.absoluteString == "https://example.com/1284x2778.png")
    }

    @Test
    func loadScreenshotSetsUsesRelationshipInstances() async throws {
        final class RequestCounter: @unchecked Sendable {
            var paths: [String] = []
        }
        let counter = RequestCounter()
        let session = MockURLProtocol.makeSession { request in
            counter.paths.append(request.url?.path ?? "")
            if request.url?.path == "/v1/appStoreVersionLocalizations/loc-1/relationships/appScreenshotSets" {
                return (
                    200,
                    """
                    {
                      "data": [{ "type": "appScreenshotSets", "id": "set-1" }]
                    }
                    """.data(using: .utf8)!
                )
            }
            #expect(request.url?.path == "/v1/appScreenshotSets/set-1")
            #expect(request.url?.query?.contains("include=appScreenshots") == true)

            return (
                200,
                """
                {
                  "data": {
                    "id": "set-1",
                    "type": "appScreenshotSets",
                    "attributes": { "screenshotDisplayType": "APP_IPHONE_65" },
                    "relationships": {
                      "appScreenshots": {
                        "data": [{ "type": "appScreenshots", "id": "shot-1" }]
                      }
                    }
                  },
                  "included": [{
                    "id": "shot-1",
                    "type": "appScreenshots",
                    "attributes": {
                      "fileName": "screen.png",
                      "fileSize": 512,
                      "imageAsset": {
                        "templateUrl": "https://example.com/{w}x{h}.{f}",
                        "width": 100,
                        "height": 200
                      }
                    }
                  }]
                }
                """.data(using: .utf8)!
            )
        }
        let client = ConnectClient(
            credentialsProvider: { Self.validCredentials() },
            session: session
        )

        let payload = try await client.loadScreenshotSets(localizationID: "loc-1")

        #expect(counter.paths.count == 2)
        #expect(payload.sets.count == 1)
        #expect(payload.sets.first?.screenshotDisplayType == "APP_IPHONE_65")
        #expect(payload.screenshotsBySetID["set-1"]?.count == 1)
        #expect(payload.screenshotsBySetID["set-1"]?.first?.fileName == "screen.png")
    }

    @Test
    func listScreenshotsBuildsExpectedRequest() async throws {
        final class RequestCounter: @unchecked Sendable {
            var paths: [String] = []
        }
        let counter = RequestCounter()
        let session = MockURLProtocol.makeSession { request in
            counter.paths.append(request.url?.path ?? "")
            if request.url?.path == "/v1/appScreenshotSets/set-1/appScreenshots" {
                return (200, Data("{\"data\":[]}".utf8))
            }
            #expect(request.url?.path == "/v1/appScreenshots")
            #expect(request.url?.query?.contains("filter%5BappScreenshotSet%5D=set-1") == true)

            return (
                200,
                """
                {
                  "data": [{
                    "id": "shot-1",
                    "type": "appScreenshots",
                    "attributes": {
                      "fileName": "screenshot-1.png",
                      "fileSize": 2048,
                      "imageAsset": {
                        "templateUrl": "https://example.com/{w}x{h}.{f}",
                        "width": 120,
                        "height": 120
                      }
                    }
                  }]
                }
                """.data(using: .utf8)!
            )
        }
        let client = ConnectClient(
            credentialsProvider: { Self.validCredentials() },
            session: session
        )

        let screenshots = try await client.listScreenshots(screenshotSetID: "set-1")

        #expect(counter.paths.count == 2)
        #expect(screenshots.count == 1)
        #expect(screenshots.first?.fileName == "screenshot-1.png")
        #expect(screenshots.first?.previewURL?.absoluteString == "https://example.com/120x120.png")
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
        let client = ConnectClient(
            credentialsProvider: { Self.validCredentials() },
            session: session
        )

        let apps = try await client.listApps(search: "Lumi", limit: 5)

        #expect(apps.count == 1)
        #expect(apps.first?.name == "Lumi")
        #expect(apps.first?.iconURL?.absoluteString == "https://example.com/64x64.png")
    }

    @Test
    func listAppsToleratesDuplicateIncludedIconIDs() async throws {
        let session = MockURLProtocol.makeSession { _ in
            (
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
                        "templateUrl": "https://example.com/first-{w}x{h}.{f}"
                      }
                    }
                  }, {
                    "id": "icon-1",
                    "type": "buildIcons",
                    "attributes": {
                      "iconAsset": {
                        "templateUrl": "https://example.com/duplicate-{w}x{h}.{f}"
                      }
                    }
                  }]
                }
                """.data(using: .utf8)!
            )
        }
        let client = ConnectClient(
            credentialsProvider: { Self.validCredentials() },
            session: session
        )

        let apps = try await client.listApps()

        #expect(apps.first?.iconURL?.absoluteString == "https://example.com/first-64x64.png")
    }

    @Test
    func connectCacheExpiresEntriesAfterTTL() {
        let cache = ConnectCache(ttl: 10, maxEntries: 8)
        let now = Date(timeIntervalSince1970: 1_000)

        cache.set("key", data: Data("value".utf8), now: now)
        #expect(cache.get("key", now: now.addingTimeInterval(5)) != nil)
        #expect(cache.get("key", now: now.addingTimeInterval(11)) == nil)
    }

    @Test
    func connectCacheEvictsOldestEntryAtCapacity() {
        let cache = ConnectCache(ttl: 60, maxEntries: 2)
        let t0 = Date(timeIntervalSince1970: 1_000)
        let t1 = t0.addingTimeInterval(1)
        let t2 = t0.addingTimeInterval(2)

        cache.set("a", data: Data("a".utf8), now: t0)
        cache.set("b", data: Data("b".utf8), now: t1)
        cache.set("c", data: Data("c".utf8), now: t2)

        #expect(cache.get("a", now: t2) == nil)
        #expect(cache.get("b", now: t2) != nil)
        #expect(cache.get("c", now: t2) != nil)
    }

    @Test
    func connectClientReusesCachedGETResponses() async throws {
        final class RequestCounter: @unchecked Sendable {
            var count = 0
        }
        let counter = RequestCounter()
        let response = """
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
            }
          }]
        }
        """.data(using: .utf8)!
        let session = MockURLProtocol.makeSession { _ in
            counter.count += 1
            return (200, response)
        }
        let cache = ConnectAPICache(
            rootDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("PluginASCClientTests-\(UUID().uuidString)", isDirectory: true),
            memoryCache: ConnectCache(ttl: 60, maxEntries: 8)
        )
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
        _ = try await client.listApps(limit: 1)

        #expect(counter.count == 1)
    }

    @Test
    func connectClientBypassesCacheWhenNetworkOnly() async throws {
        final class RequestCounter: @unchecked Sendable {
            var count = 0
        }
        let counter = RequestCounter()
        let response = """
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
            }
          }]
        }
        """.data(using: .utf8)!
        let session = MockURLProtocol.makeSession { _ in
            counter.count += 1
            return (200, response)
        }
        let cache = ConnectAPICache(
            rootDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("PluginASCClientTests-\(UUID().uuidString)", isDirectory: true),
            memoryCache: ConnectCache(ttl: 60, maxEntries: 8)
        )
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
        client.fetchPolicy = .networkOnly
        _ = try await client.listApps(limit: 1)

        #expect(counter.count == 2)
    }

    @Test
    func clientRejectsMissingCredentialsBeforeSendingRequest() async throws {
        let session = MockURLProtocol.makeSession { _ in
            Issue.record("Request should not be sent when credentials are incomplete")
            return (200, #"{"data":[]}"#.data(using: .utf8)!)
        }
        let client = ConnectClient(
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
        let client = ConnectClient(
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

    @Test
    func sidebarVersionsReturnsAllPlatformsSortedByCreatedDate() {
        let versions = [
            AppStoreVersion(
                id: "ready-old",
                platform: "IOS",
                versionString: "2.2.28",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "READY_FOR_DISTRIBUTION",
                createdDate: Date(timeIntervalSince1970: 1)
            ),
            AppStoreVersion(
                id: "ready-new",
                platform: "IOS",
                versionString: "2.2.28",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "READY_FOR_DISTRIBUTION",
                createdDate: Date(timeIntervalSince1970: 2)
            ),
            AppStoreVersion(
                id: "prepare",
                platform: "IOS",
                versionString: "2.2.28",
                appStoreState: "PREPARE_FOR_SUBMISSION",
                appVersionState: "PREPARE_FOR_SUBMISSION",
                createdDate: Date(timeIntervalSince1970: 0)
            ),
            AppStoreVersion(
                id: "mac",
                platform: "MAC_OS",
                versionString: "2.2.28",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "READY_FOR_DISTRIBUTION",
                createdDate: Date(timeIntervalSince1970: 3)
            ),
            AppStoreVersion(
                id: "latest",
                platform: "IOS",
                versionString: "3.4.3",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "READY_FOR_DISTRIBUTION",
                createdDate: Date(timeIntervalSince1970: 10)
            )
        ]

        let sidebar = AppStoreVersion.sidebarVersions(from: versions, appPlatform: "IOS")

        #expect(sidebar.count == 5)
        #expect(sidebar[0].id == "latest")
        #expect(sidebar[1].id == "mac")
        #expect(sidebar[2].id == "ready-new")
        #expect(sidebar[3].id == "ready-old")
        #expect(sidebar[4].id == "prepare")
    }

    @MainActor
    @Test
    func availableScreenshotDisplayTypesUseSelectedVersionPlatformDefaults() {
        let viewModel = VM()
        viewModel.selectedApp = AppStoreApp(
            id: "app-1",
            name: "Test",
            bundleID: "com.example.test",
            sku: "test",
            primaryLocale: "en-US",
            platform: "IOS"
        )
        viewModel.selectedVersion = AppStoreVersion(
            id: "version-1",
            platform: "MAC_OS",
            versionString: "1.0.0",
            appStoreState: "PREPARE_FOR_SUBMISSION",
            appVersionState: "PREPARE_FOR_SUBMISSION",
            createdDate: nil
        )

        let types = viewModel.availableScreenshotDisplayTypes

        #expect(types.contains("APP_DESKTOP"))
        #expect(types.contains("APP_IPHONE_67") == false)
    }

    @MainActor
    @Test
    func availableScreenshotDisplayTypesUseTvOSDefaults() {
        let viewModel = VM()
        viewModel.selectedVersion = AppStoreVersion(
            id: "version-tv",
            platform: "TV_OS",
            versionString: "1.0.0",
            appStoreState: "PREPARE_FOR_SUBMISSION",
            appVersionState: "PREPARE_FOR_SUBMISSION",
            createdDate: nil
        )

        let types = viewModel.availableScreenshotDisplayTypes

        #expect(types.contains("APP_APPLE_TV"))
        #expect(types.contains("APP_IPHONE_67") == false)
    }

    @MainActor
    @Test
    func availableScreenshotDisplayTypesUseVisionOSWithoutIOSFallback() {
        let viewModel = VM()
        viewModel.selectedVersion = AppStoreVersion(
            id: "version-vision",
            platform: "VISION_OS",
            versionString: "1.0.0",
            appStoreState: "PREPARE_FOR_SUBMISSION",
            appVersionState: "PREPARE_FOR_SUBMISSION",
            createdDate: nil
        )

        let types = viewModel.availableScreenshotDisplayTypes

        #expect(types.contains("APP_IPHONE_67") == false)
    }

    @MainActor
    @Test
    func pluginExposesAgentTools() {
        let context = LumiPluginContext(
            activeSectionID: AppStoreConnectPlugin.id,
            activeSectionTitle: AppStoreConnectPlugin.displayName
        )
        let tools = AppStoreConnectPlugin.agentTools(context: context)

        #expect(!tools.isEmpty)
        let IDs = tools.map { type(of: $0).info.id }
        #expect(IDs.contains("app-store-connect.list-apps"))
        #expect(IDs.contains("app-store-connect.list-versions"))
        #expect(IDs.contains("app-store-connect.list-localizations"))
        #expect(IDs.contains("app-store-connect.list-screenshot-sets"))
        #expect(IDs.contains("app-store-connect.list-screenshots"))
        #expect(IDs.contains("app-store-connect.list-ci-products"))
        #expect(IDs.contains("app-store-connect.create-cover-art"))
        #expect(IDs.contains("app-store-connect.list-cover-art"))
        #expect(IDs.contains("app-store-connect.read-cover-art"))
        #expect(IDs.contains("app-store-connect.update-cover-art"))
        #expect(IDs.contains("app-store-connect.export-cover-art"))
        #expect(IDs.contains("app-store-connect.read-ci-workflow"))
        #expect(IDs.contains("app-store-connect.list-ci-build-runs"))
        #expect(IDs.contains("app-store-connect.update-localization"))
        #expect(IDs.contains("app-store-connect.create-screenshot-set"))
        #expect(IDs.contains("app-store-connect.start-ci-build-run"))
        #expect(IDs.contains("app-store-connect.set-ci-workflow-enabled"))
        #expect(IDs.contains("app-store-connect.create-version"))
    }

    @Test
    func appStoreVersionCreatePayloadIncludesAppRelationship() throws {
        let body = try ConnectClient.makeAppStoreVersionCreateBody(
            appID: "app-1",
            versionString: "1.2.0",
            platform: "ios",
            releaseType: "MANUAL"
        )
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = try #require(object?["data"] as? [String: Any])
        let attributes = try #require(data["attributes"] as? [String: Any])
        let relationships = try #require(data["relationships"] as? [String: Any])
        let app = try #require(relationships["app"] as? [String: Any])
        let appData = try #require(app["data"] as? [String: Any])

        #expect(data["type"] as? String == "appStoreVersions")
        #expect(attributes["versionString"] as? String == "1.2.0")
        #expect(attributes["platform"] as? String == "IOS")
        #expect(attributes["releaseType"] as? String == "MANUAL")
        #expect(appData["id"] as? String == "app-1")
    }

    @Test
    func appStoreVersionLocalizationCreatePayloadIncludesVersionRelationship() throws {
        let attributes = AppStoreVersionLocalization.CreateAttributes(
            promotionalText: "Promo",
            description: "Desc",
            keywords: "key",
            whatsNew: "",
            supportURL: "https://example.com/support",
            marketingURL: "https://example.com"
        )
        let body = try ConnectClient.makeAppStoreVersionLocalizationCreateBody(
            versionID: "version-1",
            locale: "en-US",
            attributes: attributes
        )
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = try #require(object?["data"] as? [String: Any])
        let payloadAttributes = try #require(data["attributes"] as? [String: Any])
        let relationships = try #require(data["relationships"] as? [String: Any])
        let version = try #require(relationships["appStoreVersion"] as? [String: Any])
        let versionData = try #require(version["data"] as? [String: Any])

        #expect(data["type"] as? String == "appStoreVersionLocalizations")
        #expect(payloadAttributes["locale"] as? String == "en-US")
        #expect(payloadAttributes["description"] as? String == "Desc")
        #expect(versionData["id"] as? String == "version-1")
    }

    @Test
    func versionStringValidatorAcceptsCommonFormats() {
        #expect(VersionStringValidator.isValid("1"))
        #expect(VersionStringValidator.isValid("1.0"))
        #expect(VersionStringValidator.isValid("2.3.1"))
        #expect(VersionStringValidator.isValid("10.20.30"))
        #expect(VersionStringValidator.isValid("1.0-beta") == false)
        #expect(VersionStringValidator.isValid("") == false)
    }

    @Test
    func suggestedNextVersionStringBumpsPatchOnSamePlatform() {
        let versions = [
            AppStoreVersion(
                id: "ios-old",
                platform: "IOS",
                versionString: "2.1.0",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "READY_FOR_SALE",
                createdDate: Date(timeIntervalSince1970: 1)
            ),
            AppStoreVersion(
                id: "ios-new",
                platform: "IOS",
                versionString: "2.3.4",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "READY_FOR_SALE",
                createdDate: Date(timeIntervalSince1970: 10)
            ),
            AppStoreVersion(
                id: "mac",
                platform: "MAC_OS",
                versionString: "9.9.9",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "READY_FOR_SALE",
                createdDate: Date(timeIntervalSince1970: 3)
            )
        ]

        #expect(AppStoreVersion.suggestedNextVersionString(for: "IOS", in: versions) == "2.3.5")
        #expect(AppStoreVersion.suggestedNextVersionString(for: "MAC_OS", in: versions) == "9.9.10")
        #expect(AppStoreVersion.suggestedNextVersionString(for: "TV_OS", in: versions) == "2.3.5")
    }

    @Test
    func suggestedNextVersionStringSkipsExistingVersionOnPlatform() {
        let versions = [
            AppStoreVersion(
                id: "ios-current",
                platform: "IOS",
                versionString: "2.3.5",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "READY_FOR_SALE",
                createdDate: nil
            )
        ]

        #expect(AppStoreVersion.suggestedNextVersionString(for: "IOS", in: versions) == "2.3.6")
    }

    @Test
    func suggestedNextVersionStringFallsBackToOneZeroZero() {
        #expect(AppStoreVersion.suggestedNextVersionString(for: "IOS", in: []) == "1.0.0")
    }

    @Test
    func validateCreateRejectsInProgressPlatform() {
        let versions = [
            AppStoreVersion(
                id: "prepare",
                platform: "IOS",
                versionString: "1.0.0",
                appStoreState: "PREPARE_FOR_SUBMISSION",
                appVersionState: "PREPARE_FOR_SUBMISSION",
                createdDate: nil
            )
        ]

        #expect(throws: VersionCreateValidationError.self) {
            try AppStoreVersion.validateCreate(
                versionString: "1.0.1",
                platform: "IOS",
                versions: versions
            )
        }
        #expect(AppStoreVersion.isPlatformAvailableForVersionCreate("MAC_OS", versions: versions))
    }

    @Test
    func validateCreateRejectsDuplicateVersionStringOnPlatform() {
        let versions = [
            AppStoreVersion(
                id: "ready",
                platform: "IOS",
                versionString: "1.0.0",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "READY_FOR_SALE",
                createdDate: nil
            )
        ]

        #expect(throws: VersionCreateValidationError.self) {
            try AppStoreVersion.validateCreate(
                versionString: "1.0.0",
                platform: "IOS",
                versions: versions
            )
        }
    }

    @Test
    func createVersionPostsToAppStoreVersionsEndpoint() async throws {
        final class RequestRecorder: @unchecked Sendable {
            var method: String?
            var path: String?
        }
        let recorder = RequestRecorder()
        let response = """
        {
          "data": {
            "id": "version-new",
            "type": "appStoreVersions",
            "attributes": {
              "platform": "IOS",
              "versionString": "1.0.1",
              "appStoreState": "PREPARE_FOR_SUBMISSION",
              "appVersionState": "PREPARE_FOR_SUBMISSION",
              "createdDate": "2026-06-18T10:00:00Z"
            }
          }
        }
        """.data(using: .utf8)!
        let session = MockURLProtocol.makeSession { request in
            recorder.method = request.httpMethod
            recorder.path = request.url?.path
            return (201, response)
        }
        let client = ConnectClient(
            credentialsProvider: { Self.validCredentials() },
            session: session
        )

        let created = try await client.createVersion(
            appID: "app-1",
            versionString: "1.0.1",
            platform: "IOS"
        )

        #expect(recorder.method == "POST")
        #expect(recorder.path == "/v1/appStoreVersions")
        #expect(created.id == "version-new")
        #expect(created.versionString == "1.0.1")
    }

    @MainActor
    @Test
    func canCreateVersionReflectsPlatformAvailability() {
        let viewModel = VM()
        viewModel.selectedApp = AppStoreApp(
            id: "app-1",
            name: "Test",
            bundleID: "com.example.test",
            sku: "test",
            primaryLocale: "en-US",
            platform: "IOS"
        )
        viewModel.versions = [
            AppStoreVersion(
                id: "prepare",
                platform: "IOS",
                versionString: "1.0.0",
                appStoreState: "PREPARE_FOR_SUBMISSION",
                appVersionState: "PREPARE_FOR_SUBMISSION",
                createdDate: nil
            )
        ]

        #expect(viewModel.isPlatformAvailableForVersionCreate("IOS") == false)
        #expect(viewModel.canCreateVersion == false)
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
