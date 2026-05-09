import XCTest
@testable import XcodeKit

final class XcodeEditorContextSnapshotTests: XCTestCase {

    // MARK: - XcodeEditorContextSnapshot Tests

    func testSnapshotInitialization() {
        let snapshot = XcodeEditorContextSnapshot(
            projectPath: "/test/project.xcodeproj",
            workspaceName: "TestWorkspace",
            workspacePath: "/test/TestWorkspace.xcworkspace",
            activeScheme: "App",
            activeSchemeBuildableTargets: ["App", "AppTests"],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            schemes: ["App", "AppTests"],
            configurations: ["Debug", "Release"],
            currentFilePath: "/test/file.swift",
            currentFileTarget: "App",
            currentFileMatchedTargets: ["App"],
            currentFileIsInTarget: true
        )

        XCTAssertEqual(snapshot.projectPath, "/test/project.xcodeproj")
        XCTAssertEqual(snapshot.workspaceName, "TestWorkspace")
        XCTAssertEqual(snapshot.activeScheme, "App")
        XCTAssertEqual(snapshot.activeSchemeBuildableTargets, ["App", "AppTests"])
        XCTAssertEqual(snapshot.currentFileTarget, "App")
        XCTAssertTrue(snapshot.currentFileIsInTarget)
    }

    func testSnapshotEquality() {
        let lhs = XcodeEditorContextSnapshot(
            projectPath: "/test",
            workspaceName: "WS",
            workspacePath: "/test/WS.xcworkspace",
            activeScheme: "App",
            activeSchemeBuildableTargets: [],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            schemes: ["App"],
            configurations: ["Debug"],
            currentFilePath: "/test/file.swift",
            currentFileTarget: "App",
            currentFileMatchedTargets: ["App"],
            currentFileIsInTarget: true
        )
        let rhs = lhs
        XCTAssertEqual(lhs, rhs)
    }

    func testSnapshotInequality() {
        let lhs = XcodeEditorContextSnapshot(
            projectPath: "/test1",
            workspaceName: "WS",
            workspacePath: "/test1/WS.xcworkspace",
            activeScheme: "App",
            activeSchemeBuildableTargets: [],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            schemes: ["App"],
            configurations: ["Debug"],
            currentFilePath: "/test/file.swift",
            currentFileTarget: "App",
            currentFileMatchedTargets: ["App"],
            currentFileIsInTarget: true
        )
        var rhs = lhs
        // Note: Since it's a struct, we need to create a different one
        let rhs2 = XcodeEditorContextSnapshot(
            projectPath: "/test2",
            workspaceName: "WS",
            workspacePath: "/test2/WS.xcworkspace",
            activeScheme: "App",
            activeSchemeBuildableTargets: [],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            schemes: ["App"],
            configurations: ["Debug"],
            currentFilePath: "/test/file.swift",
            currentFileTarget: "App",
            currentFileMatchedTargets: ["App"],
            currentFileIsInTarget: true
        )
        XCTAssertNotEqual(lhs, rhs2)
    }

    func testSnapshotEmptyMatchedTargets() {
        let snapshot = XcodeEditorContextSnapshot(
            projectPath: "/test",
            workspaceName: "WS",
            workspacePath: "/test/WS.xcworkspace",
            activeScheme: nil,
            activeSchemeBuildableTargets: [],
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Not Initialized",
            isXcodeProject: true,
            schemes: [],
            configurations: [],
            currentFilePath: "/test/file.swift",
            currentFileTarget: nil,
            currentFileMatchedTargets: [],
            currentFileIsInTarget: false
        )

        XCTAssertNil(snapshot.activeScheme)
        XCTAssertNil(snapshot.activeConfiguration)
        XCTAssertNil(snapshot.currentFileTarget)
        XCTAssertTrue(snapshot.currentFileMatchedTargets.isEmpty)
        XCTAssertFalse(snapshot.currentFileIsInTarget)
    }

    // MARK: - BridgeCachedState Tests

    func testBridgeCachedStateInitialization() {
        let state = BridgeCachedState(
            workspaceFolders: [["uri": "file:///test", "name": "Test"]],
            buildServerPath: "/path/buildServer.json",
            activeScheme: "App",
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            isInitialized: true,
            workspaceName: "TestWorkspace",
            workspacePath: "/test/TestWorkspace.xcworkspace",
            schemes: ["App", "AppTests"],
            configurations: ["Debug", "Release"],
            projectPath: "/test/project.xcodeproj"
        )

        XCTAssertNotNil(state.workspaceFolders)
        XCTAssertEqual(state.workspaceFolders?.count, 1)
        XCTAssertEqual(state.buildServerPath, "/path/buildServer.json")
        XCTAssertEqual(state.activeScheme, "App")
        XCTAssertEqual(state.schemes, ["App", "AppTests"])
        XCTAssertTrue(state.isXcodeProject)
        XCTAssertTrue(state.isInitialized)
    }

    func testBridgeCachedStateEmpty() {
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Not Initialized",
            isXcodeProject: false,
            isInitialized: false,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: nil
        )

        XCTAssertNil(state.workspaceFolders)
        XCTAssertNil(state.buildServerPath)
        XCTAssertFalse(state.isXcodeProject)
        XCTAssertFalse(state.isInitialized)
    }

    func testBridgeCachedStructures() {
        // Verify it's a struct with value semantics
        var state1 = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: "/path1",
            activeScheme: "App",
            activeConfiguration: "Debug",
            activeDestination: nil,
            buildContextStatus: "Available",
            isXcodeProject: true,
            isInitialized: true,
            workspaceName: "WS",
            workspacePath: "/ws",
            schemes: ["App"],
            configurations: ["Debug"],
            projectPath: "/test"
        )
        var state2 = state1
        state2.activeScheme = "Other"
        XCTAssertEqual(state1.activeScheme, "App")
        XCTAssertEqual(state2.activeScheme, "Other")
    }
}
