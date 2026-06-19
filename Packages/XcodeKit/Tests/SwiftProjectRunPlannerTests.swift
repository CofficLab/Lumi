import XCTest
@testable import XcodeKit

@MainActor
final class SwiftProjectRunPlannerTests: XCTestCase {

    private var storeRoot: URL!
    private var store: XcodeBuildServerStore!

    override func setUp() {
        super.setUp()
        storeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: storeRoot, withIntermediateDirectories: true)
        store = XcodeBuildServerStore(pluginDirectoryURL: storeRoot)
    }

    func testSPMPreflightSelectsSingleExecutable() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let manifest = """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "Demo",
            targets: [
                .executableTarget(name: "Demo"),
            ]
        )
        """
        try manifest.write(
            to: tempDir.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let result = await SwiftProjectRunPlanner.preflight(
            provider: nil,
            projectPath: tempDir.path,
            currentFileURL: nil,
            store: store
        )

        XCTAssertTrue(result.isReady)
        if case let .spm(packageRoot, executableTarget, configuration)? = result.context {
            XCTAssertEqual(packageRoot.path, tempDir.path)
            XCTAssertEqual(executableTarget, "Demo")
            XCTAssertEqual(configuration, "debug")
        } else {
            XCTFail("Expected SPM context")
        }
    }

    func testSPMPreflightNeedsTargetSelectionForMultipleExecutables() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let manifest = """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "Demo",
            targets: [
                .executableTarget(name: "One"),
                .executableTarget(name: "Two"),
            ]
        )
        """
        try manifest.write(
            to: tempDir.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let result = await SwiftProjectRunPlanner.preflight(
            provider: nil,
            projectPath: tempDir.path,
            currentFileURL: nil,
            store: store
        )

        XCTAssertFalse(result.isReady)
        XCTAssertEqual(result.failure, .needsTargetSelection(["One", "Two"]))
    }

    func testXcodePreflightFindsRunnableApplicationTargetInMinimalAppFixture() async throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/MinimalApp.xcodeproj", isDirectory: true)
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw XCTSkip("MinimalApp fixture missing")
        }

        let resolver = XcodeProjectResolver()
        let workspace = await resolver.resolve(workspaceURL: fixtureURL)
        XCTAssertNotNil(workspace)

        let appTarget = workspace?.projects.flatMap(\.targets).first { $0.name == "MinimalApp" }
        XCTAssertEqual(appTarget?.productType, "com.apple.product-type.application")

        let result = await SwiftProjectRunPlanner.preflight(
            provider: nil,
            projectPath: fixtureURL.deletingLastPathComponent().path,
            currentFileURL: nil,
            store: store,
            fallbackScheme: "MinimalApp"
        )

        XCTAssertTrue(result.isReady, result.disabledReason ?? "expected ready preflight")
        if case let .xcode(_, scheme, _, _, _, preferredTargetName)? = result.context {
            XCTAssertEqual(scheme, "MinimalApp")
            XCTAssertEqual(preferredTargetName, "MinimalApp")
        } else {
            XCTFail("Expected Xcode run context")
        }
    }
}
