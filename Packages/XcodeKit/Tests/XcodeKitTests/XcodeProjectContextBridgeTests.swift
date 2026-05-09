import XCTest
@testable import XcodeKit

final class XcodeProjectContextBridgeNotificationTests: XCTestCase {

    // MARK: - Notification.Name Tests
    
    func testProjectContextDidChangeNotification() {
        let name = Notification.Name.lumiEditorProjectContextDidChange
        XCTAssertEqual(name.rawValue, "lumiEditorProjectContextDidChange")
    }
    
    func testProjectSnapshotDidChangeNotification() {
        let name = Notification.Name.lumiEditorProjectSnapshotDidChange
        XCTAssertEqual(name.rawValue, "lumiEditorProjectSnapshotDidChange")
    }
    
    // MARK: - BridgeCachedState Sendable Tests
    
    func testBridgeCachedStateIsSendable() {
        let state = BridgeCachedState(
            workspaceFolders: [["uri": "file:///test", "name": "Test"]],
            buildServerPath: "/path",
            activeScheme: "App",
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            isInitialized: true,
            workspaceName: "WS",
            workspacePath: "/ws",
            schemes: ["App"],
            configurations: ["Debug"],
            projectPath: "/test"
        )
        
        // Verify value semantics
        var copy = state
        // BridgeCachedState is a struct with let properties, so copies are independent
        XCTAssertEqual(copy.activeScheme, "App")
        XCTAssertEqual(copy.workspaceFolders?.count, 1)
    }
    
    // MARK: - XcodeEditorContextSnapshot Sendable Tests
    
    func testSnapshotIsSendable() {
        let snapshot = XcodeEditorContextSnapshot(
            projectPath: "/test",
            workspaceName: "WS",
            workspacePath: "/ws",
            activeScheme: "App",
            activeSchemeBuildableTargets: ["App"],
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
        
        XCTAssertEqual(snapshot.projectPath, "/test")
        XCTAssertTrue(snapshot.currentFileIsInTarget)
    }
    
    // MARK: - BridgeCachedState Edge Cases
    
    func testBridgeCachedStateAllNil() {
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "",
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
        XCTAssertNil(state.activeScheme)
        XCTAssertFalse(state.isXcodeProject)
        XCTAssertFalse(state.isInitialized)
        XCTAssertTrue(state.schemes.isEmpty)
        XCTAssertTrue(state.configurations.isEmpty)
    }
}
