#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class XcodeSemanticIndexRunnerTests: XCTestCase {
    func testCompileDatabaseURLUsesHiddenCompileFile() {
        let directory = URL(fileURLWithPath: "/tmp/store")
        XCTAssertEqual(
            XcodeSemanticIndexRunner.compileDatabaseURL(in: directory).lastPathComponent,
            ".compile"
        )
    }

    func testCompileDatabaseFreshWhenNewerThanBuildServerJSON() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XcodeSemanticIndexRunnerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let buildServerURL = tempDirectory.appendingPathComponent("buildServer.json")
        let compileURL = tempDirectory.appendingPathComponent(".compile")
        FileManager.default.createFile(atPath: buildServerURL.path, contents: Data("{}".utf8))
        Thread.sleep(forTimeInterval: 0.01)
        FileManager.default.createFile(atPath: compileURL.path, contents: Data("compile".utf8))

        XCTAssertTrue(
            XcodeSemanticIndexRunner.isCompileDatabaseFresh(
                compileDatabaseURL: compileURL,
                buildServerJSONURL: buildServerURL
            )
        )

        try FileManager.default.removeItem(at: tempDirectory)
    }

    func testCompileDatabaseNotFreshWhenMissing() {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-compile-\(UUID().uuidString)", isDirectory: true)
        let buildServerURL = tempDirectory.appendingPathComponent("buildServer.json")
        let compileURL = tempDirectory.appendingPathComponent(".compile")

        XCTAssertFalse(
            XcodeSemanticIndexRunner.isCompileDatabaseFresh(
                compileDatabaseURL: compileURL,
                buildServerJSONURL: buildServerURL
            )
        )
    }

    func testDiscoverBuildRootFindsNewestDerivedDataSubdirectory() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("discover-build-root-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let older = tempDirectory.appendingPathComponent("OlderProject-oldhash", isDirectory: true)
        let newer = tempDirectory.appendingPathComponent("Lumi-newhash", isDirectory: true)
        try FileManager.default.createDirectory(at: older.appendingPathComponent("Build"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newer.appendingPathComponent("Logs"), withIntermediateDirectories: true)
        Thread.sleep(forTimeInterval: 0.01)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-60)],
            ofItemAtPath: older.path
        )

        XCTAssertEqual(
            URL(fileURLWithPath: XcodeSemanticIndexRunner.discoverBuildRoot(in: tempDirectory) ?? "")
                .standardizedFileURL,
            newer.standardizedFileURL
        )
    }

    func testSyncRequiresManagedBuildRoot() async {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("managed-build-root-\(UUID().uuidString)", isDirectory: true)
        let derivedDataDirectory = tempDirectory.appendingPathComponent("DerivedData", isDirectory: true)
        let request = XcodeSemanticIndexRunner.Request(
            workspaceURL: URL(fileURLWithPath: "/tmp/Example.xcodeproj"),
            scheme: "Example",
            configuration: "Debug",
            destinationQuery: "platform=macOS",
            storeDirectory: tempDirectory,
            derivedDataDirectory: derivedDataDirectory,
            xcodeBuildServerPath: "/usr/bin/false",
            buildRoot: "/Users/test/Library/Developer/Xcode/DerivedData/Lumi-systemhash"
        )

        let synced = await XcodeSemanticIndexRunner.syncCompileDatabaseFromDerivedData(request)
        XCTAssertFalse(synced)
    }

    func testBuildAndParseDoesNotCrashWhenStoreDirectoryMissing() async {
        let missingStore = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-store-\(UUID().uuidString)", isDirectory: true)

        let request = XcodeSemanticIndexRunner.Request(
            workspaceURL: URL(fileURLWithPath: "/tmp/Example.xcodeproj"),
            scheme: "Example",
            configuration: "Debug",
            destinationQuery: "platform=macOS",
            storeDirectory: missingStore,
            derivedDataDirectory: missingStore.appendingPathComponent("DerivedData", isDirectory: true),
            xcodeBuildServerPath: "/usr/bin/false",
            buildRoot: nil
        )

        let failureReason = await XcodeSemanticIndexRunner.buildAndParseCompileDatabase(request)
        XCTAssertNotNil(failureReason)
    }

    func testProcessRunWithSharedLogHandleMatchesRunnerBehavior() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("process-log-handle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let logURL = tempDirectory.appendingPathComponent("semantic-index-build.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try XCTUnwrap(FileHandle(forWritingTo: logURL))
        defer { try? logHandle.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/echo")
        process.arguments = ["process-launch-ok"]
        process.currentDirectoryURL = tempDirectory
        process.standardOutput = logHandle
        process.standardError = logHandle

        XCTAssertNoThrow(try process.run())
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testProcessRunWithSharedLogHandleAndMissingWorkingDirectoryThrows() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("process-missing-cwd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let missingWorkingDirectory = tempDirectory.appendingPathComponent("does-not-exist", isDirectory: true)
        let logURL = tempDirectory.appendingPathComponent("semantic-index-build.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        let logHandle = try FileHandle(forWritingTo: logURL)
        defer { try? logHandle.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/echo")
        process.arguments = ["should-fail"]
        process.currentDirectoryURL = missingWorkingDirectory
        process.standardOutput = logHandle
        process.standardError = logHandle

        XCTAssertThrowsError(try process.run())
    }

    func testBuildAndParseWithExistingStoreAndInvalidWorkspaceReturnsFalseWithoutCrashing() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("semantic-index-build-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let request = XcodeSemanticIndexRunner.Request(
            workspaceURL: URL(fileURLWithPath: "/tmp/Example.xcodeproj"),
            scheme: "Example",
            configuration: "Debug",
            destinationQuery: "platform=macOS",
            storeDirectory: tempDirectory,
            derivedDataDirectory: tempDirectory.appendingPathComponent("DerivedData", isDirectory: true),
            xcodeBuildServerPath: "/usr/bin/false",
            buildRoot: nil
        )

        let failureReason = await XcodeSemanticIndexRunner.buildAndParseCompileDatabase(request)
        XCTAssertNotNil(failureReason)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: tempDirectory.appendingPathComponent("semantic-index-build.log").path
            )
        )
    }

    func testNormalizedFailureReasonPrefersErrorLine() {
        let raw = """
        note: building target
        some verbose output
        error: no such module 'LumiCoreKit'
        """
        let reason = XcodeSemanticIndexRunner.normalizedFailureReason(raw)
        XCTAssertEqual(reason, "error: no such module 'LumiCoreKit'")
    }

    func testCompileDatabaseHasEntriesReturnsFalseForEmptyArray() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("compile-db-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let compileURL = tempDirectory.appendingPathComponent(".compile")
        try Data("[]".utf8).write(to: compileURL)

        XCTAssertFalse(XcodeSemanticIndexRunner.compileDatabaseHasEntries(at: compileURL))
    }

    func testCompileDatabaseHasEntriesReturnsTrueForNonEmptyArray() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("compile-db-nonempty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let compileURL = tempDirectory.appendingPathComponent(".compile")
        try Data("[{\"file\":\"a.swift\"}]".utf8).write(to: compileURL)

        XCTAssertTrue(XcodeSemanticIndexRunner.compileDatabaseHasEntries(at: compileURL))
    }
}
#endif
