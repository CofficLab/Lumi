import Testing
import Foundation
@testable import PluginAppStoreConnect

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
}
