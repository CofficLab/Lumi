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
        
        // Verify value semantics — struct with let properties, copies are independent
        let copy = state
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

    @MainActor
    func testShouldHaveBuildContextUsesLiveProjectFlag() {
        let bridge = XcodeProjectContextBridge.shared
        defer { bridge.projectClosed() }

        bridge.projectClosed()
        XCTAssertFalse(bridge.shouldHaveBuildContext)

        bridge.isXcodeProject = true
        XCTAssertTrue(bridge.shouldHaveBuildContext)
    }

    // MARK: - buildServerPath gating on .compile

    func testCompileDatabaseNotReadyWhenMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BridgeCompileGating-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let buildServerJSONPath = directory.appendingPathComponent("buildServer.json").path
        FileManager.default.createFile(atPath: buildServerJSONPath, contents: Data("{}".utf8))

        XCTAssertFalse(
            XcodeProjectContextBridge.isCompileDatabaseReady(forBuildServerJSONPath: buildServerJSONPath),
            "buildServer.json without a sibling .compile must be treated as not ready"
        )
    }

    func testCompileDatabaseReadyWhenSiblingExists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BridgeCompileGating-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let buildServerJSONPath = directory.appendingPathComponent("buildServer.json").path
        FileManager.default.createFile(atPath: buildServerJSONPath, contents: Data("{}".utf8))
        FileManager.default.createFile(
            atPath: directory.appendingPathComponent(".compile").path,
            contents: Data("[]".utf8)
        )

        XCTAssertTrue(
            XcodeProjectContextBridge.isCompileDatabaseReady(forBuildServerJSONPath: buildServerJSONPath),
            "A .compile next to buildServer.json must mark the build server as ready for sourcekit-lsp"
        )
    }
}
