import XCTest
@testable import LumiKernel

final class LumiRuntimeEnvironmentTests: XCTestCase {
    func testDebugConfigurationUsesIsolatedIdentifiers() {
        let environment = LumiRuntimeEnvironment.resolve(
            infoDictionary: [
                "LumiEnvironment": "debug",
                "LumiAppGroupIdentifier": "group.com.coffic.lumi.debug",
                "LumiURLScheme": "lumi-debug",
                "LumiKeychainServiceSuffix": ".debug",
                "LumiAllowsAppUpdates": "NO",
            ],
            bundleIdentifier: "com.coffic.lumi.debug"
        )

        XCTAssertTrue(environment.isDebug)
        XCTAssertEqual(environment.appGroupIdentifier, "group.com.coffic.lumi.debug")
        XCTAssertEqual(environment.urlScheme, "lumi-debug")
        XCTAssertEqual(
            environment.keychainService(for: "com.coffic.lumi.apikey"),
            "com.coffic.lumi.apikey.debug"
        )
        XCTAssertFalse(environment.allowsAppUpdates)
    }

    func testReleaseConfigurationPreservesHistoricalIdentifiers() {
        let environment = LumiRuntimeEnvironment.resolve(
            infoDictionary: [
                "LumiEnvironment": "release",
                "LumiAppGroupIdentifier": "group.com.coffic.lumi",
                "LumiURLScheme": "lumi",
                "LumiKeychainServiceSuffix": "",
                "LumiAllowsAppUpdates": "YES",
            ],
            bundleIdentifier: "com.coffic.lumi"
        )

        XCTAssertFalse(environment.isDebug)
        XCTAssertEqual(environment.appGroupIdentifier, "group.com.coffic.lumi")
        XCTAssertEqual(environment.urlScheme, "lumi")
        XCTAssertEqual(
            environment.keychainService(for: "com.coffic.lumi.apikey"),
            "com.coffic.lumi.apikey"
        )
        XCTAssertTrue(environment.allowsAppUpdates)
    }

    func testDebugBundleIdentifierProvidesSafeFallbacksForMissingBuildSettings() {
        let environment = LumiRuntimeEnvironment.resolve(
            infoDictionary: [:],
            bundleIdentifier: "com.coffic.lumi.debug"
        )

        XCTAssertTrue(environment.isDebug)
        XCTAssertEqual(environment.appGroupIdentifier, "group.com.coffic.lumi.debug")
        XCTAssertEqual(environment.urlScheme, "lumi-debug")
        XCTAssertEqual(environment.keychainServiceSuffix, ".debug")
        XCTAssertFalse(environment.allowsAppUpdates)
    }
}
