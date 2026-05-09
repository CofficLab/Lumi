import XCTest
@testable import XcodeKit

final class XcodeProjectContextTests: XCTestCase {

    // MARK: - XcodeDestinationContext Tests

    func testDestinationContextEquality() {
        let lhs = XcodeDestinationContext(id: "macOS-arm64", platform: "macOS", arch: "arm64", name: "My Mac (arm64)", destinationQuery: "platform=macOS,arch=arm64")
        let rhs = XcodeDestinationContext(id: "macOS-arm64", platform: "macOS", arch: "arm64", name: "My Mac (arm64)", destinationQuery: "platform=macOS,arch=arm64")
        XCTAssertEqual(lhs, rhs)
    }

    func testDestinationContextInequality() {
        let lhs = XcodeDestinationContext(id: "macOS-arm64", platform: "macOS", arch: "arm64", name: "My Mac (arm64)", destinationQuery: "platform=macOS,arch=arm64")
        let rhs = XcodeDestinationContext(id: "macOS-x86_64", platform: "macOS", arch: "x86_64", name: "My Mac (x86_64)", destinationQuery: "platform=macOS,arch=x86_64")
        XCTAssertNotEqual(lhs, rhs)
    }

    func testMacOSDefaultDestination() {
        let dest = XcodeDestinationContext.macOSDefault()
        XCTAssertEqual(dest.id, "macOS-arm64")
        XCTAssertEqual(dest.platform, "macOS")
        XCTAssertEqual(dest.arch, "arm64")
        XCTAssertTrue(dest.name.hasPrefix("My Mac"))
        XCTAssertTrue(dest.destinationQuery.hasPrefix("platform=macOS"))
    }

    func testMacOSDefaultWithCustomArch() {
        let dest = XcodeDestinationContext.macOSDefault(arch: "x86_64")
        XCTAssertEqual(dest.arch, "x86_64")
        XCTAssertEqual(dest.id, "macOS-x86_64")
    }

    // MARK: - XcodeBuildConfigurationContext Tests

    func testBuildConfigurationEquality() {
        let lhs = XcodeBuildConfigurationContext(id: "debug_1", name: "Debug", settings: ["SWIFT_OPTIMIZATION_LEVEL": "-Onone"])
        let rhs = XcodeBuildConfigurationContext(id: "debug_1", name: "Debug", settings: ["OTHER": "value"])
        XCTAssertEqual(lhs, rhs)
    }

    func testBuildConfigurationDefaultSettings() {
        let config = XcodeBuildConfigurationContext(id: "debug", name: "Debug")
        XCTAssertTrue(config.settings.isEmpty)
    }

    // MARK: - XcodeTargetContext Tests

    func testTargetEquality() {
        let lhs = XcodeTargetContext(id: "app", name: "App", productType: "application", buildConfigurations: [], sourceFiles: [])
        let rhs = XcodeTargetContext(id: "app", name: "App", productType: "application", buildConfigurations: [], sourceFiles: [])
        XCTAssertEqual(lhs, rhs)
    }

    func testTargetWithSourceFiles() {
        let files: Set<String> = ["/path/to/file1.swift", "/path/to/file2.swift"]
        let target = XcodeTargetContext(id: "app", name: "App", productType: "application", buildConfigurations: [], sourceFiles: files)
        XCTAssertEqual(target.sourceFiles.count, 2)
        XCTAssertTrue(target.sourceFiles.contains("/path/to/file1.swift"))
    }

    // MARK: - XcodeSchemeContext Tests

    func testSchemeContextEquality() {
        let lhs = XcodeSchemeContext(id: "app", name: "App", buildableTargets: ["App"], defaultConfiguration: "Debug")
        let rhs = XcodeSchemeContext(id: "app", name: "App", buildableTargets: ["App"], defaultConfiguration: "Debug")
        XCTAssertEqual(lhs, rhs)
    }

    func testSchemeDefaultConfiguration() {
        let scheme = XcodeSchemeContext(id: "app", name: "App", buildableTargets: ["App"], defaultConfiguration: nil)
        XCTAssertEqual(scheme.activeConfiguration, "Debug")
        XCTAssertNil(scheme.activeDestination)
    }

    // MARK: - XcodeProjectContext Tests

    func testProjectEquality() {
        let url = URL(filePath: "/test/project.xcodeproj")
        let lhs = XcodeProjectContext(id: "/test/project.xcodeproj", name: "project", path: url, targets: [], buildConfigurations: [], schemes: [])
        let rhs = XcodeProjectContext(id: "/test/project.xcodeproj", name: "project", path: url, targets: [], buildConfigurations: [], schemes: [])
        XCTAssertEqual(lhs, rhs)
    }

    // MARK: - XcodeWorkspaceContext Tests

    func testWorkspaceRootURL() {
        let url = URL(filePath: "/test/MyProject.xcworkspace")
        let workspace = XcodeWorkspaceContext(id: "/test/MyProject.xcworkspace", name: "MyProject", path: url, projects: [], schemes: [])
        XCTAssertEqual(workspace.rootURL.path, "/test")
    }

    func testWorkspaceRootURLNonWorkspace() {
        let url = URL(filePath: "/test/MyProject.xcodeproj")
        let workspace = XcodeWorkspaceContext(id: "/test/MyProject.xcodeproj", name: "MyProject", path: url, projects: [], schemes: [])
        XCTAssertEqual(workspace.rootURL, url)
    }

    func testWorkspaceEquality() {
        let url = URL(filePath: "/test/workspace.xcworkspace")
        let lhs = XcodeWorkspaceContext(id: "1", name: "WS", path: url, projects: [], schemes: [])
        let rhs = XcodeWorkspaceContext(id: "1", name: "WS", path: url, projects: [], schemes: [])
        XCTAssertEqual(lhs, rhs)
    }

    func testWorkspaceInequality() {
        let url1 = URL(filePath: "/test/workspace1.xcworkspace")
        let url2 = URL(filePath: "/test/workspace2.xcworkspace")
        let lhs = XcodeWorkspaceContext(id: "1", name: "WS", path: url1, projects: [], schemes: [])
        let rhs = XcodeWorkspaceContext(id: "2", name: "WS", path: url2, projects: [], schemes: [])
        XCTAssertNotEqual(lhs, rhs)
    }
}
