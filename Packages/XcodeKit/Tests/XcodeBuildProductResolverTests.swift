import XCTest
@testable import XcodeKit

final class XcodeBuildProductResolverTests: XCTestCase {

    func testResolvesAppBundleFromBuildSettings() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let appBundle = tempDir.appendingPathComponent("MinimalApp.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appBundle, withIntermediateDirectories: true)
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.createDirectory(at: infoPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: infoPlist)

        let settings: [String: String] = [
            "BUILT_PRODUCTS_DIR": tempDir.path,
            "FULL_PRODUCT_NAME": "MinimalApp.app",
        ]

        let product = XcodeBuildProductResolver.resolveFromBuildSettings(settings)
        XCTAssertEqual(product?.path, appBundle.path)
    }

    func testPrefersPreferredTargetSettings() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let appBundle = tempDir.appendingPathComponent("App.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appBundle, withIntermediateDirectories: true)
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.createDirectory(at: infoPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: infoPlist)

        let allSettings: [[String: String]] = [
            [
                "TARGET_NAME": "Tests",
                "BUILT_PRODUCTS_DIR": tempDir.path,
                "FULL_PRODUCT_NAME": "Tests.xctest",
            ],
            [
                "TARGET_NAME": "App",
                "BUILT_PRODUCTS_DIR": tempDir.path,
                "FULL_PRODUCT_NAME": "App.app",
            ],
        ]

        let product = XcodeBuildProductResolver.resolveFromBuildSettings(allSettings, preferredTargetNames: ["App"])
        XCTAssertEqual(product?.lastPathComponent, "App.app")
    }

    func testResolvesAppFromDerivedDataDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let derivedData = tempDir.appendingPathComponent("DerivedData", isDirectory: true)
        let productsDir = derivedData
            .appendingPathComponent("Build/Products/Debug", isDirectory: true)
        try FileManager.default.createDirectory(at: productsDir, withIntermediateDirectories: true)

        let appBundle = productsDir.appendingPathComponent("GitOK.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appBundle, withIntermediateDirectories: true)
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.createDirectory(at: infoPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: infoPlist)

        let product = XcodeBuildProductResolver.resolveFromDerivedDataDirectory(
            derivedData,
            configuration: "Debug",
            preferredTargetNames: ["GitOK"]
        )
        XCTAssertEqual(product?.lastPathComponent, "GitOK.app")
    }

    func testResolvesAppFromBuildOutputPath() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let derivedData = tempDir.appendingPathComponent("DerivedData", isDirectory: true)
        let productsDir = derivedData
            .appendingPathComponent("Build/Products/Debug", isDirectory: true)
        try FileManager.default.createDirectory(at: productsDir, withIntermediateDirectories: true)

        let appBundle = productsDir.appendingPathComponent("GitOK.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appBundle, withIntermediateDirectories: true)
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.createDirectory(at: infoPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: infoPlist)

        let output = """
        Validate \(appBundle.path) (in target 'GitOK' from project 'GitOK')
            builtin-validationUtility \(appBundle.path) -no-validate-extension -infoplist-subpath Contents/Info.plist
        ** BUILD SUCCEEDED **
        """
        let product = XcodeBuildProductResolver.resolveFromBuildOutput(
            output,
            preferredTargetNames: ["GitOK"],
            derivedDataDirectory: derivedData
        )
        XCTAssertEqual(product?.path, appBundle.path)
    }

    func testResolvesAppFromBuildOutputWithEscapedSpacesInPath() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let applicationSupport = tempDir
            .appendingPathComponent("Application Support", isDirectory: true)
        let derivedData = applicationSupport
            .appendingPathComponent("com.coffic.lumi/db_debug/EditorSwiftPlugin/hash/DerivedData", isDirectory: true)
        let productsDir = derivedData
            .appendingPathComponent("Build/Products/Debug", isDirectory: true)
        try FileManager.default.createDirectory(at: productsDir, withIntermediateDirectories: true)

        let appBundle = productsDir.appendingPathComponent("GitOK.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appBundle, withIntermediateDirectories: true)
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.createDirectory(at: infoPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: infoPlist)

        let escapedPath = appBundle.path
            .replacingOccurrences(of: " ", with: "\\ ")
        let output = """
        Validate \(escapedPath) (in target 'GitOK' from project 'GitOK')
            builtin-validationUtility \(escapedPath) -no-validate-extension -infoplist-subpath Contents/Info.plist
        ** BUILD SUCCEEDED **
        """
        let product = XcodeBuildProductResolver.resolveFromBuildOutput(
            output,
            preferredTargetNames: ["GitOK"],
            derivedDataDirectory: derivedData
        )
        XCTAssertEqual(product?.path, appBundle.path)
    }

    func testResolveXcodeProductPrefersDerivedDataOverBuildSettings() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let derivedData = tempDir.appendingPathComponent("DerivedData", isDirectory: true)
        let productsDir = derivedData
            .appendingPathComponent("Build/Products/Debug", isDirectory: true)
        try FileManager.default.createDirectory(at: productsDir, withIntermediateDirectories: true)

        let appBundle = productsDir.appendingPathComponent("GitOK.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appBundle, withIntermediateDirectories: true)
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.createDirectory(at: infoPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: infoPlist)

        let staleSettings: [[String: String]] = [[
            "TARGET_NAME": "GitOK",
            "BUILT_PRODUCTS_DIR": "/tmp/DoesNotExist",
            "FULL_PRODUCT_NAME": "GitOK.app",
        ]]

        let product = XcodeBuildProductResolver.resolveXcodeProduct(
            buildSettings: staleSettings,
            derivedDataDirectory: derivedData,
            configuration: "Debug",
            preferredTargetNames: ["GitOK"],
            buildOutput: ""
        )
        XCTAssertEqual(product?.path, appBundle.path)
    }
}
