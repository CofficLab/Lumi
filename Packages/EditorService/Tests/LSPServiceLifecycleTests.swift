#if canImport(XCTest)
import XCTest
@testable import EditorService

final class LSPServerLifecyclePolicyTests: XCTestCase {
    func testBuildServerPathChangeRequiresServerRestart() {
        XCTAssertFalse(
            LSPServerLifecyclePolicy.canReuseExistingServer(
                hasServer: true,
                activeLanguageId: "swift",
                requestedLanguageId: "swift",
                activeProjectPath: "/Users/me/Lumi",
                requestedProjectPath: "/Users/me/Lumi",
                activeBuildServerPath: nil,
                requestedBuildServerPath: "/tmp/buildServer.json"
            ),
            "SourceKit must restart once buildServerPath becomes available"
        )
    }

    func testLegacyReuseLogicIgnoredBuildServerPathChange() {
        XCTAssertTrue(
            LSPServerLifecyclePolicy.legacyCanReuseExistingServer(
                hasServer: true,
                activeLanguageId: "swift",
                requestedLanguageId: "swift",
                activeProjectPath: "/Users/me/Lumi",
                requestedProjectPath: "/Users/me/Lumi"
            ),
            "Old ensureServer guard reused the server even after buildServerPath became available"
        )

        XCTAssertFalse(
            LSPServerLifecyclePolicy.canReuseExistingServer(
                hasServer: true,
                activeLanguageId: "swift",
                requestedLanguageId: "swift",
                activeProjectPath: "/Users/me/Lumi",
                requestedProjectPath: "/Users/me/Lumi",
                activeBuildServerPath: nil,
                requestedBuildServerPath: "/tmp/buildServer.json"
            )
        )
    }

    func testBuildServerPathExtractsInitializationOption() {
        XCTAssertEqual(
            LSPServerLifecyclePolicy.buildServerPath(from: ["buildServerPath": "/tmp/buildServer.json"]),
            "/tmp/buildServer.json"
        )
        XCTAssertNil(LSPServerLifecyclePolicy.buildServerPath(from: [:]))
        XCTAssertNil(LSPServerLifecyclePolicy.buildServerPath(from: nil))
    }
}

@MainActor
final class LSPServiceInitializationOptionsTests: XCTestCase {
    private final class MockLanguageIntegrationCapability: SuperEditorLanguageIntegrationCapability {
        let id = "mock.language.integration"
        var buildServerPath: String?

        func supports(languageId: String, projectPath: String?) -> Bool {
            languageId == "swift" && projectPath != nil
        }

        func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]? {
            [EditorWorkspaceFolder(uri: "file://\(projectPath)", name: "Lumi")]
        }

        func initializationOptions(for languageId: String, projectPath: String) -> [String: String]? {
            guard let buildServerPath else { return nil }
            return ["buildServerPath": buildServerPath, "scheme": "Lumi"]
        }
    }

    override func setUp() async throws {
        let registry = EditorExtensionRegistry()
        registry.registerLanguageIntegrationCapability(MockLanguageIntegrationCapability())
        LSPService.shared.configureRegistry(registry)
    }

    override func tearDown() async throws {
        LSPService.shared.stopAll()
        LSPService.shared.configureRegistry(EditorExtensionRegistry())
    }

    func testInitializationOptionsMissingUntilBuildServerIsReady() {
        let capability = MockLanguageIntegrationCapability()
        capability.buildServerPath = nil
        let registry = EditorExtensionRegistry()
        registry.registerLanguageIntegrationCapability(capability)
        LSPService.shared.configureRegistry(registry)

        XCTAssertNil(
            LSPService.makeInitializationOptions(for: "swift", projectPath: "/Users/me/Lumi")
        )
        XCTAssertNil(
            LSPService.currentBuildServerPath(for: "swift", projectPath: "/Users/me/Lumi")
        )
    }

    func testInitializationOptionsIncludeBuildServerPathWhenReady() {
        let capability = MockLanguageIntegrationCapability()
        capability.buildServerPath = "/tmp/buildServer.json"
        let registry = EditorExtensionRegistry()
        registry.registerLanguageIntegrationCapability(capability)
        LSPService.shared.configureRegistry(registry)

        XCTAssertNotNil(
            LSPService.makeInitializationOptions(for: "swift", projectPath: "/Users/me/Lumi")
        )
        XCTAssertEqual(
            LSPService.currentBuildServerPath(for: "swift", projectPath: "/Users/me/Lumi"),
            "/tmp/buildServer.json"
        )
    }
}
#endif
