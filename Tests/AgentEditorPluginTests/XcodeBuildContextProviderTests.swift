#if canImport(XCTest)
import XCTest
@testable import Lumi

final class XcodeBuildContextProviderTests: XCTestCase {
    func testBuildSettingsCacheKeyIncludesAllDimensions() {
        let debugMac = XcodeBuildContextProvider.buildSettingsCacheKey(
            workspaceID: "workspace-a",
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS"
        )
        let releaseMac = XcodeBuildContextProvider.buildSettingsCacheKey(
            workspaceID: "workspace-a",
            scheme: "App",
            configuration: "Release",
            destination: "platform=macOS"
        )
        let debugIOS = XcodeBuildContextProvider.buildSettingsCacheKey(
            workspaceID: "workspace-a",
            scheme: "App",
            configuration: "Debug",
            destination: "platform=iOS Simulator"
        )

        XCTAssertNotEqual(debugMac, releaseMac)
        XCTAssertNotEqual(debugMac, debugIOS)
    }

    func testBuildSettingsCacheKeyFallsBackToDefaultDestination() {
        let key = XcodeBuildContextProvider.buildSettingsCacheKey(
            workspaceID: "workspace-a",
            scheme: "App",
            configuration: "Debug",
            destination: nil
        )

        XCTAssertEqual(key, "workspace-a|App|Debug|default")
    }

    func testCacheKeySchemeMatchUsesSchemeSlotOnly() {
        let key = "workspace-App|Feature|Debug|platform=macOS"

        XCTAssertTrue(XcodeBuildContextProvider.cacheKey(key, matchesScheme: "Feature"))
        XCTAssertFalse(XcodeBuildContextProvider.cacheKey(key, matchesScheme: "App"))
    }

    func testInvalidatedBuildSettingsCacheRemovesOnlyMatchingSchemeEntries() {
        let cache = [
            "workspace-a|App|Debug|default": [["PRODUCT_NAME": "App"]],
            "workspace-a|App|Release|default": [["PRODUCT_NAME": "App"]],
            "workspace-a|Widget|Debug|default": [["PRODUCT_NAME": "Widget"]]
        ]

        let invalidated = XcodeBuildContextProvider.invalidatedBuildSettingsCache(
            cache,
            removingScheme: "App"
        )

        XCTAssertEqual(invalidated.count, 1)
        XCTAssertNotNil(invalidated["workspace-a|Widget|Debug|default"])
    }

    func testSelectBestSchemePrefersProjectNameOverDependencyScheme() {
        let schemes = [
            XcodeSchemeContext(id: "dep", name: "SwiftTreeSitter", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "app", name: "Lumi", buildableTargets: [], defaultConfiguration: "Debug"),
            XcodeSchemeContext(id: "tests", name: "LumiTests", buildableTargets: [], defaultConfiguration: "Debug")
        ]

        let selected = XcodeBuildContextProvider.selectBestScheme(
            schemes: schemes,
            projectName: "Lumi",
            targets: ["Lumi", "LumiTests"]
        )

        XCTAssertEqual(selected?.name, "Lumi")
    }

    func testResolvedSchemeSelectionAppliesDefaultConfigurationAndDestination() {
        let unresolved = XcodeSchemeContext(
            id: "app",
            name: "Lumi",
            buildableTargets: [],
            defaultConfiguration: "Release",
            activeConfiguration: "",
            activeDestination: nil
        )

        let resolved = XcodeBuildContextProvider.resolvedSchemeSelection(
            unresolved,
            fallbackDestination: .macOSDefault(arch: "arm64")
        )

        XCTAssertEqual(resolved.activeConfiguration, "Release")
        XCTAssertEqual(resolved.activeDestination?.destinationQuery, "platform=macOS,arch=arm64")
    }

    func testResolvedSchemeConfigurationOverridesActiveConfigurationOnly() {
        let scheme = XcodeSchemeContext(
            id: "app",
            name: "Lumi",
            buildableTargets: [],
            defaultConfiguration: "Debug",
            activeConfiguration: "Debug",
            activeDestination: .macOSDefault(arch: "x86_64")
        )

        let updated = XcodeBuildContextProvider.resolvedSchemeConfiguration(scheme, configuration: "Release")

        XCTAssertEqual(updated.activeConfiguration, "Release")
        XCTAssertEqual(updated.activeDestination?.destinationQuery, "platform=macOS,arch=x86_64")
    }
}
#endif
