import XCTest
@testable import XcodeKit

final class XcodeBuildServerStoreTests: XCTestCase {
    
    var store: XcodeBuildServerStore!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        store = XcodeBuildServerStore(pluginDirectoryURL: tempDirectory)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - ensureDirectory Tests
    
    func testEnsureDirectoryCreatesDirectory() {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory = store.ensureDirectory(forWorkspace: workspacePath)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertTrue(directory.path.hasPrefix(tempDirectory.path))
    }
    
    func testEnsureDirectoryIdempotent() {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory1 = store.ensureDirectory(forWorkspace: workspacePath)
        let directory2 = store.ensureDirectory(forWorkspace: workspacePath)
        
        XCTAssertEqual(directory1, directory2)
    }
    
    func testEnsureDirectoryDifferentWorkspaces() {
        let workspace1 = "/Users/test/Project1.xcworkspace"
        let workspace2 = "/Users/test/Project2.xcworkspace"
        
        let dir1 = store.ensureDirectory(forWorkspace: workspace1)
        let dir2 = store.ensureDirectory(forWorkspace: workspace2)
        
        XCTAssertNotEqual(dir1, dir2)
    }

    func testDerivedDataDirectoryIsUnderProjectStore() {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let storeDirectory = store.ensureDirectory(forWorkspace: workspacePath)
        let derivedDataDirectory = store.derivedDataDirectory(forWorkspace: workspacePath)

        XCTAssertEqual(
            derivedDataDirectory.deletingLastPathComponent(),
            storeDirectory
        )
        XCTAssertEqual(derivedDataDirectory.lastPathComponent, "DerivedData")
    }

    func testIsManagedBuildRootAcceptsPluginLocalPath() {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let derivedDataDirectory = store.derivedDataDirectory(forWorkspace: workspacePath)
        let buildRoot = derivedDataDirectory
            .appendingPathComponent("Lumi-abc123", isDirectory: true)
            .path

        XCTAssertTrue(store.isManagedBuildRoot(buildRoot, forWorkspace: workspacePath))
    }

    func testIsManagedBuildRootRejectsSystemDerivedData() {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let buildRoot = "/Users/test/Library/Developer/Xcode/DerivedData/Lumi-abc123"

        XCTAssertFalse(store.isManagedBuildRoot(buildRoot, forWorkspace: workspacePath))
    }

    func testUpdateBuildRootPersistsValue() throws {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory = store.ensureDirectory(forWorkspace: workspacePath)
        let fileURL = directory.appendingPathComponent("buildServer.json")

        let json: [String: Any] = [
            "workspace": workspacePath,
            "scheme": "MyScheme",
            "build_root": "/old/path"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: fileURL)

        let newBuildRoot = store.derivedDataDirectory(forWorkspace: workspacePath)
            .appendingPathComponent("Lumi-newhash", isDirectory: true)
            .path
        XCTAssertTrue(store.updateBuildRoot(forWorkspace: workspacePath, buildRoot: newBuildRoot))

        let updated = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        XCTAssertEqual(updated?["build_root"] as? String, newBuildRoot)
    }

    func testUpdateBuildRootSkipsRewriteWhenUnchanged() throws {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory = store.ensureDirectory(forWorkspace: workspacePath)
        let fileURL = directory.appendingPathComponent("buildServer.json")

        let buildRoot = store.derivedDataDirectory(forWorkspace: workspacePath).path
        let json: [String: Any] = [
            "workspace": workspacePath,
            "scheme": "MyScheme",
            "build_root": buildRoot,
        ]
        try JSONSerialization.data(withJSONObject: json).write(to: fileURL)

        let before = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
        // Re-applying the same build_root (even with a trailing slash) must not rewrite the file,
        // otherwise the file's mtime would jump ahead of `.compile` and trigger an endless re-index.
        Thread.sleep(forTimeInterval: 0.02)
        XCTAssertTrue(store.updateBuildRoot(forWorkspace: workspacePath, buildRoot: buildRoot + "/"))
        let after = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date

        XCTAssertEqual(before, after, "Unchanged build_root must not rewrite buildServer.json")
    }
    
    // MARK: - load Tests
    
    func testLoadReturnsNilForNonexistentWorkspace() {
        let result = store.load(forWorkspace: "/nonexistent/path.xcworkspace")
        XCTAssertNil(result)
    }
    
    func testLoadParsesValidBuildServerJSON() throws {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory = store.ensureDirectory(forWorkspace: workspacePath)
        let fileURL = directory.appendingPathComponent("buildServer.json")
        
        let json: [String: Any] = [
            "workspace": workspacePath,
            "scheme": "MyScheme"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: fileURL)
        
        let config = store.load(forWorkspace: workspacePath)
        
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.workspacePath, workspacePath)
        XCTAssertEqual(config?.scheme, "MyScheme")
        XCTAssertEqual(config?.buildServerJSONPath, fileURL.path)
    }
    
    func testLoadReturnsNilForInvalidJSON() throws {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory = store.ensureDirectory(forWorkspace: workspacePath)
        let fileURL = directory.appendingPathComponent("buildServer.json")
        let corruptURL = directory.appendingPathComponent("buildServer.corrupt.json")
        
        try "invalid json".write(to: fileURL, atomically: true, encoding: .utf8)
        
        let config = store.load(forWorkspace: workspacePath)
        XCTAssertNil(config)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptURL.path))
    }

    func testLoadCanRecoverAfterQuarantiningInvalidJSON() throws {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory = store.ensureDirectory(forWorkspace: workspacePath)
        let fileURL = directory.appendingPathComponent("buildServer.json")

        try "invalid json".write(to: fileURL, atomically: true, encoding: .utf8)
        XCTAssertNil(store.load(forWorkspace: workspacePath))

        let json: [String: Any] = [
            "workspace": workspacePath,
            "scheme": "RecoveredScheme"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: fileURL)

        let config = store.load(forWorkspace: workspacePath)
        XCTAssertEqual(config?.workspacePath, workspacePath)
        XCTAssertEqual(config?.scheme, "RecoveredScheme")
    }
    
    // MARK: - validate Tests
    
    func testValidateReturnsNilForMismatchedWorkspace() throws {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory = store.ensureDirectory(forWorkspace: workspacePath)
        let fileURL = directory.appendingPathComponent("buildServer.json")
        
        let json: [String: Any] = [
            "workspace": "/different/path.xcworkspace",
            "scheme": "MyScheme"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: fileURL)
        
        let config = store.validate(forWorkspace: workspacePath)
        XCTAssertNil(config)
    }
    
    func testValidateReturnsNilForEmptyScheme() throws {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory = store.ensureDirectory(forWorkspace: workspacePath)
        let fileURL = directory.appendingPathComponent("buildServer.json")
        
        let json: [String: Any] = [
            "workspace": workspacePath,
            "scheme": ""
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: fileURL)
        
        let config = store.validate(forWorkspace: workspacePath)
        XCTAssertNil(config)
    }
    
    func testValidateReturnsConfigForValidJSON() throws {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        let directory = store.ensureDirectory(forWorkspace: workspacePath)
        let fileURL = directory.appendingPathComponent("buildServer.json")
        
        let json: [String: Any] = [
            "workspace": workspacePath,
            "scheme": "MyScheme"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: fileURL)
        
        let config = store.validate(forWorkspace: workspacePath)
        
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.workspacePath, workspacePath)
        XCTAssertEqual(config?.scheme, "MyScheme")
    }
    
    // MARK: - remove Tests
    
    func testRemoveDeletesDirectory() throws {
        let workspacePath = "/Users/test/MyProject.xcworkspace"
        store.ensureDirectory(forWorkspace: workspacePath)
        
        store.remove(forWorkspace: workspacePath)
        
        // Verify load returns nil after removal
        let config = store.load(forWorkspace: workspacePath)
        XCTAssertNil(config)
    }
    
    // MARK: - removeAll Tests
    
    func testRemoveAllDeletesRootDirectory() throws {
        let workspace1 = "/Users/test/Project1.xcworkspace"
        let workspace2 = "/Users/test/Project2.xcworkspace"
        
        store.ensureDirectory(forWorkspace: workspace1)
        store.ensureDirectory(forWorkspace: workspace2)
        
        store.removeAll()
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.path))
    }
    
    // MARK: - Config Model Tests
    
    func testConfigEquality() {
        let config1 = XcodeBuildServerStore.Config(
            buildServerJSONPath: "/path/buildServer.json",
            workspacePath: "/path/workspace.xcworkspace",
            scheme: "Scheme"
        )
        let config2 = XcodeBuildServerStore.Config(
            buildServerJSONPath: "/path/buildServer.json",
            workspacePath: "/path/workspace.xcworkspace",
            scheme: "Scheme"
        )
        
        XCTAssertEqual(config1, config2)
    }
    
    func testConfigInequality() {
        let config1 = XcodeBuildServerStore.Config(
            buildServerJSONPath: "/path1/buildServer.json",
            workspacePath: "/path1/workspace.xcworkspace",
            scheme: "Scheme1"
        )
        let config2 = XcodeBuildServerStore.Config(
            buildServerJSONPath: "/path2/buildServer.json",
            workspacePath: "/path2/workspace.xcworkspace",
            scheme: "Scheme2"
        )
        
        XCTAssertNotEqual(config1, config2)
    }
    
    // MARK: - String MD5 Extension Tests
    
    func testMD5HashConsistency() {
        let string = "test string"
        let hash1 = string.md5Hash
        let hash2 = string.md5Hash
        
        XCTAssertEqual(hash1, hash2)
    }
    
    func testMD5HashDifferentForDifferentStrings() {
        let string1 = "test1"
        let string2 = "test2"
        
        XCTAssertNotEqual(string1.md5Hash, string2.md5Hash)
    }
    
    func testMD5HashFormat() {
        let hash = "test".md5Hash
        
        // MD5 should be 32 hex characters
        XCTAssertEqual(hash.count, 32)
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }
}
