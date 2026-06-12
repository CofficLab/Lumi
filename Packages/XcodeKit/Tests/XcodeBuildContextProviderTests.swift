import XCTest
@testable import XcodeKit

@MainActor
final class XcodeBuildContextProviderTests: XCTestCase {
    
    // MARK: - selectBestScheme Tests
    
    func testSelectBestSchemeEmptyReturnsNil() {
        let result = XcodeBuildContextProvider.selectBestScheme(
            schemes: [],
            projectName: "MyProject",
            targets: []
        )
        XCTAssertNil(result)
    }
    
    func testSelectBestSchemeMatchesProjectName() {
        let schemes = [
            XcodeSchemeContext(id: "App", name: "App", buildableTargets: ["App"], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "MyProject", name: "MyProject", buildableTargets: ["MyProject"], defaultConfiguration: "Debug"),
        ]
        
        let result = XcodeBuildContextProvider.selectBestScheme(
            schemes: schemes,
            projectName: "MyProject",
            targets: ["MyProject"]
        )
        
        XCTAssertEqual(result?.name, "MyProject")
    }
    
    func testSelectBestSchemeMatchesTargetName() {
        let schemes = [
            XcodeSchemeContext(id: "Lib-Package", name: "Lib-Package", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "MyTarget", name: "MyTarget", buildableTargets: ["MyTarget"], defaultConfiguration: "Debug"),
        ]
        
        let result = XcodeBuildContextProvider.selectBestScheme(
            schemes: schemes,
            projectName: "MyProject",
            targets: ["MyTarget"]
        )
        
        XCTAssertEqual(result?.name, "MyTarget")
    }
    
    func testSelectBestSchemeExcludesPackageSchemes() {
        let schemes = [
            XcodeSchemeContext(id: "s1", name: "SomeLib-Package", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "s2", name: "SwiftTreeSitter", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "s3", name: "EditorLanguages", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "s4", name: "TextStory", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "s5", name: "GoodScheme", buildableTargets: ["GoodScheme"], defaultConfiguration: "Debug"),
        ]
        
        let result = XcodeBuildContextProvider.selectBestScheme(
            schemes: schemes,
            projectName: "MyProject",
            targets: ["GoodScheme"]
        )
        
        XCTAssertEqual(result?.name, "GoodScheme")
    }
    
    func testSelectBestSchemeExcludesTestingSchemes() {
        let schemes = [
            XcodeSchemeContext(id: "s1", name: "Lib-Testing", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "s2", name: "LibTesting", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "s3", name: "MyApp", buildableTargets: ["MyApp"], defaultConfiguration: "Debug"),
        ]
        
        let result = XcodeBuildContextProvider.selectBestScheme(
            schemes: schemes,
            projectName: "MyProject",
            targets: ["MyApp"]
        )
        
        XCTAssertEqual(result?.name, "MyApp")
    }
    
    func testSelectBestSchemeExcludesSemaphore() {
        let schemes = [
            XcodeSchemeContext(id: "s1", name: "Semaphore", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "s2", name: "RealTarget", buildableTargets: ["RealTarget"], defaultConfiguration: "Debug"),
        ]
        
        let result = XcodeBuildContextProvider.selectBestScheme(
            schemes: schemes,
            projectName: "MyProject",
            targets: ["RealTarget"]
        )
        
        XCTAssertEqual(result?.name, "RealTarget")
    }
    
    func testSelectBestSchemeFallsBackToFirst() {
        let schemes = [
            XcodeSchemeContext(id: "s1", name: "Lib-Package", buildableTargets: [], defaultConfiguration: "Debug"),
        ]
        
        let result = XcodeBuildContextProvider.selectBestScheme(
            schemes: schemes,
            projectName: "MyProject",
            targets: []
        )
        
        XCTAssertEqual(result?.name, "Lib-Package")
    }
    
    func testSelectBestSchemeExcludesPackageTargets() {
        let schemes = [
            XcodeSchemeContext(id: "s1", name: "MyLib-Package", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "s2", name: "MainApp", buildableTargets: ["MainApp"], defaultConfiguration: "Debug"),
        ]
        
        let result = XcodeBuildContextProvider.selectBestScheme(
            schemes: schemes,
            projectName: "MyProject",
            targets: ["MainApp"]
        )
        
        XCTAssertEqual(result?.name, "MainApp")
    }

    func testBuildableTargetOrderToleratesDuplicates() {
        let order = XcodeBuildContextProvider.buildableTargetOrder([
            "App",
            "Tests",
            "App",
            "UITests",
            "Tests",
        ])

        XCTAssertEqual(order["App"], 0)
        XCTAssertEqual(order["Tests"], 1)
        XCTAssertEqual(order["UITests"], 3)
    }
    
    // MARK: - defaultDestination Tests
    
    func testDefaultDestination() {
        let dest = XcodeBuildContextProvider.defaultDestination()
        
        XCTAssertEqual(dest.platform, "macOS")
        XCTAssertEqual(dest.id, "macOS-arm64")
        XCTAssertTrue(dest.name.contains("My Mac"))
    }
    
    // MARK: - resolvedSchemeSelection Tests
    
    func testResolvedSchemeSelectionSetsDefaultConfiguration() {
        let scheme = XcodeSchemeContext(
            id: "app",
            name: "App",
            buildableTargets: ["App"],
            defaultConfiguration: "Release",
            activeConfiguration: "",
            activeDestination: nil
        )
        let fallback = XcodeDestinationContext.macOSDefault()
        
        let resolved = XcodeBuildContextProvider.resolvedSchemeSelection(scheme, fallbackDestination: fallback)
        
        XCTAssertEqual(resolved.activeConfiguration, "Release")
        XCTAssertNotNil(resolved.activeDestination)
    }
    
    func testResolvedSchemeSelectionSetsFallbackDestination() {
        let scheme = XcodeSchemeContext(
            id: "app",
            name: "App",
            buildableTargets: ["App"],
            defaultConfiguration: nil,
            activeConfiguration: "Debug",
            activeDestination: nil
        )
        let fallback = XcodeDestinationContext.macOSDefault(arch: "x86_64")
        
        let resolved = XcodeBuildContextProvider.resolvedSchemeSelection(scheme, fallbackDestination: fallback)
        
        XCTAssertEqual(resolved.activeDestination?.arch, "x86_64")
    }
    
    func testResolvedSchemeSelectionPreservesExistingValues() {
        let existingDest = XcodeDestinationContext(
            id: "iOS-arm64",
            platform: "iOS",
            arch: "arm64",
            name: "iPhone",
            destinationQuery: "platform=iOS,arch=arm64"
        )
        let scheme = XcodeSchemeContext(
            id: "app",
            name: "App",
            buildableTargets: ["App"],
            defaultConfiguration: "Release",
            activeConfiguration: "Custom",
            activeDestination: existingDest
        )
        let fallback = XcodeDestinationContext.macOSDefault()
        
        let resolved = XcodeBuildContextProvider.resolvedSchemeSelection(scheme, fallbackDestination: fallback)
        
        XCTAssertEqual(resolved.activeConfiguration, "Custom")
        XCTAssertEqual(resolved.activeDestination?.platform, "iOS")
    }
    
    // MARK: - resolvedSchemeConfiguration Tests
    
    func testResolvedSchemeConfiguration() {
        let scheme = XcodeSchemeContext(
            id: "app",
            name: "App",
            buildableTargets: ["App"],
            defaultConfiguration: "Debug",
            activeConfiguration: "Debug",
            activeDestination: nil
        )
        
        let resolved = XcodeBuildContextProvider.resolvedSchemeConfiguration(scheme, configuration: "Release")
        
        XCTAssertEqual(resolved.activeConfiguration, "Release")
    }
    
    // MARK: - buildSettingsCacheKey Tests
    
    func testBuildSettingsCacheKey() {
        let key = XcodeBuildContextProvider.buildSettingsCacheKey(
            workspaceID: "ws1",
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS,arch=arm64"
        )
        
        XCTAssertEqual(key, "ws1|App|Debug|platform=macOS,arch=arm64")
    }
    
    func testBuildSettingsCacheKeyNilDestination() {
        let key = XcodeBuildContextProvider.buildSettingsCacheKey(
            workspaceID: "ws1",
            scheme: "App",
            configuration: "Debug",
            destination: nil
        )
        
        XCTAssertEqual(key, "ws1|App|Debug|default")
    }
    
    // MARK: - cacheKey matchesScheme Tests
    
    func testCacheKeyMatchesScheme() {
        let key = "ws1|App|Debug|default"
        
        XCTAssertTrue(XcodeBuildContextProvider.cacheKey(key, matchesScheme: "App"))
        XCTAssertFalse(XcodeBuildContextProvider.cacheKey(key, matchesScheme: "Tests"))
    }
    
    func testCacheKeyMatchesSchemeMalformedKey() {
        let key = "malformed"
        
        XCTAssertFalse(XcodeBuildContextProvider.cacheKey(key, matchesScheme: "App"))
    }
    
    // MARK: - invalidatedBuildSettingsCache Tests
    
    func testInvalidatedBuildSettingsCache() {
        let cache: [String: [[String: String]]] = [
            "ws1|App|Debug|default": [["TARGET_NAME": "App"]],
            "ws1|Tests|Debug|default": [["TARGET_NAME": "Tests"]],
            "ws1|App|Release|default": [["TARGET_NAME": "App"]],
        ]
        
        let result = XcodeBuildContextProvider.invalidatedBuildSettingsCache(
            cache,
            removingScheme: "App"
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result["ws1|Tests|Debug|default"])
    }
    
    func testInvalidatedBuildSettingsCacheRemovesAll() {
        let cache: [String: [[String: String]]] = [
            "ws1|App|Debug|default": [["TARGET_NAME": "App"]],
            "ws1|App|Release|default": [["TARGET_NAME": "App"]],
        ]
        
        let result = XcodeBuildContextProvider.invalidatedBuildSettingsCache(
            cache,
            removingScheme: "App"
        )
        
        XCTAssertTrue(result.isEmpty)
    }
    
    func testInvalidatedBuildSettingsCacheEmptyCache() {
        let result = XcodeBuildContextProvider.invalidatedBuildSettingsCache(
            [:],
            removingScheme: "App"
        )
        
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - BuildContextStatus Tests
    
    func testBuildContextStatusDisplayDescriptionUnknown() {
        let status = XcodeBuildContextProvider.BuildContextStatus.unknown
        XCTAssertEqual(status.displayDescription, "Unknown")
    }
    
    func testBuildContextStatusDisplayDescriptionResolving() {
        let status = XcodeBuildContextProvider.BuildContextStatus.resolving
        XCTAssertEqual(status.displayDescription, "Resolving build context...")
    }
    
    func testBuildContextStatusDisplayDescriptionAvailable() {
        let config = XcodeBuildContextProvider.XcodeBuildServerConfig(
            buildServerJSONPath: "/path",
            workspacePath: "/ws",
            scheme: "MyScheme"
        )
        let status = XcodeBuildContextProvider.BuildContextStatus.available(config)
        XCTAssertTrue(status.displayDescription.contains("MyScheme"))
    }
    
    func testBuildContextStatusDisplayDescriptionUnavailable() {
        let status = XcodeBuildContextProvider.BuildContextStatus.unavailable("missing tool")
        XCTAssertTrue(status.displayDescription.contains("missing tool"))
    }
    
    func testBuildContextStatusDisplayDescriptionNeedsResync() {
        let status = XcodeBuildContextProvider.BuildContextStatus.needsResync
        XCTAssertEqual(status.displayDescription, "Needs resync")
    }

    func testBuildServerGenerationStatusReportsInvalidOutputAfterSuccessfulCommand() {
        let status = XcodeBuildContextProvider.buildServerGenerationStatus(
            success: true,
            config: nil
        )

        XCTAssertEqual(
            status,
            .unavailable("Generated buildServer.json was missing or invalid")
        )
    }

    func testBuildServerGenerationStatusReportsCommandFailure() {
        let status = XcodeBuildContextProvider.buildServerGenerationStatus(
            success: false,
            config: nil
        )

        XCTAssertEqual(status, .unavailable("Failed to generate buildServer.json"))
    }
    
    // MARK: - XcodeBuildServerConfig Tests
    
    func testBuildServerConfigInit() {
        let config = XcodeBuildContextProvider.XcodeBuildServerConfig(
            buildServerJSONPath: "/path/buildServer.json",
            workspacePath: "/path/workspace.xcworkspace",
            scheme: "App"
        )
        
        XCTAssertEqual(config.buildServerJSONPath, "/path/buildServer.json")
        XCTAssertEqual(config.workspacePath, "/path/workspace.xcworkspace")
        XCTAssertEqual(config.scheme, "App")
    }
    
    func testBuildServerConfigFromStoreConfig() {
        let storeConfig = XcodeBuildServerStore.Config(
            buildServerJSONPath: "/path/buildServer.json",
            workspacePath: "/path/workspace.xcworkspace",
            scheme: "App"
        )
        
        let config = XcodeBuildContextProvider.XcodeBuildServerConfig(from: storeConfig)
        
        XCTAssertEqual(config.buildServerJSONPath, "/path/buildServer.json")
        XCTAssertEqual(config.workspacePath, "/path/workspace.xcworkspace")
        XCTAssertEqual(config.scheme, "App")
    }
    
    func testBuildServerConfigEquality() {
        let config1 = XcodeBuildContextProvider.XcodeBuildServerConfig(
            buildServerJSONPath: "/path",
            workspacePath: "/ws",
            scheme: "App"
        )
        let config2 = XcodeBuildContextProvider.XcodeBuildServerConfig(
            buildServerJSONPath: "/path",
            workspacePath: "/ws",
            scheme: "App"
        )
        
        XCTAssertEqual(config1, config2)
    }
    
    func testBuildServerConfigInequality() {
        let config1 = XcodeBuildContextProvider.XcodeBuildServerConfig(
            buildServerJSONPath: "/path1",
            workspacePath: "/ws1",
            scheme: "App"
        )
        let config2 = XcodeBuildContextProvider.XcodeBuildServerConfig(
            buildServerJSONPath: "/path2",
            workspacePath: "/ws2",
            scheme: "Tests"
        )
        
        XCTAssertNotEqual(config1, config2)
    }
    
    // MARK: - BuildContextStatus Equality Tests
    
    func testBuildContextStatusEquality() {
        XCTAssertEqual(XcodeBuildContextProvider.BuildContextStatus.unknown, .unknown)
        XCTAssertEqual(XcodeBuildContextProvider.BuildContextStatus.resolving, .resolving)
        XCTAssertEqual(XcodeBuildContextProvider.BuildContextStatus.needsResync, .needsResync)
    }
    
    func testBuildContextStatusInequality() {
        XCTAssertNotEqual(XcodeBuildContextProvider.BuildContextStatus.unknown, .resolving)
        XCTAssertNotEqual(XcodeBuildContextProvider.BuildContextStatus.resolving, .needsResync)
    }
    
    func testBuildContextStatusAvailableEquality() {
        let config = XcodeBuildContextProvider.XcodeBuildServerConfig(
            buildServerJSONPath: "/path",
            workspacePath: "/ws",
            scheme: "App"
        )
        let status1 = XcodeBuildContextProvider.BuildContextStatus.available(config)
        let status2 = XcodeBuildContextProvider.BuildContextStatus.available(config)
        
        XCTAssertEqual(status1, status2)
    }
}
