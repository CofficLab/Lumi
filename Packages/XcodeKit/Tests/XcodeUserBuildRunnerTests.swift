import XCTest
@testable import XcodeKit

final class XcodeUserBuildRunnerTests: XCTestCase {

    func testXcodebuildArgumentsUseIncrementalBuild() {
        let request = XcodeUserBuildRunner.Request(
            workspaceURL: URL(fileURLWithPath: "/tmp/App.xcodeproj"),
            scheme: "App",
            configuration: "Debug",
            destinationQuery: "platform=macOS,arch=arm64",
            derivedDataDirectory: URL(fileURLWithPath: "/tmp/DerivedData"),
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )

        let args = XcodeUserBuildRunner.xcodebuildArguments(for: request)
        XCTAssertEqual(args, [
            "-project", "/tmp/App.xcodeproj",
            "-scheme", "App",
            "-configuration", "Debug",
            "-destination", "platform=macOS,arch=arm64",
            "-derivedDataPath", "/tmp/DerivedData",
            "build",
        ])
        XCTAssertFalse(args.contains("clean"))
    }

    func testWorkspaceArguments() {
        let request = XcodeUserBuildRunner.Request(
            workspaceURL: URL(fileURLWithPath: "/tmp/App.xcworkspace"),
            scheme: "App",
            configuration: "Release",
            destinationQuery: "platform=macOS",
            derivedDataDirectory: URL(fileURLWithPath: "/tmp/DerivedData"),
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )

        let args = XcodeUserBuildRunner.xcodebuildArguments(for: request)
        XCTAssertEqual(args.first, "-workspace")
        XCTAssertEqual(args[1], "/tmp/App.xcworkspace")
    }

    func testBuildDoesNotReportCancelledWhenNotUserCancelled() async {
        let runner = XcodeUserBuildRunner()
        let request = XcodeUserBuildRunner.Request(
            workspaceURL: URL(fileURLWithPath: "/nonexistent/project.xcodeproj"),
            scheme: "Nonexistent",
            configuration: "Debug",
            destinationQuery: "platform=macOS,arch=arm64",
            derivedDataDirectory: URL(fileURLWithPath: "/tmp/DerivedData"),
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )

        let result = await runner.build(request: request) { _ in }

        XCTAssertFalse(result.wasCancelled, "Starting a new build must not mark the result as cancelled")
    }
}
