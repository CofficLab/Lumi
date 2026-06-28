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

    func testXcodebuildArgumentsPerformIncrementalBuild() {
        // Semantic indexing now uses an *incremental* build (no `clean`) and merges the partial
        // result into the existing `.compile`. Asserting that `clean` is absent is the guardrail that
        // prevents a regression to the expensive full-rebuild-on-every-reindex behavior.
        let request = XcodeSemanticIndexRunner.Request(
            workspaceURL: URL(fileURLWithPath: "/tmp/Example.xcodeproj"),
            scheme: "Lumi",
            configuration: "Debug",
            destinationQuery: "platform=macOS",
            storeDirectory: URL(fileURLWithPath: "/tmp/store"),
            derivedDataDirectory: URL(fileURLWithPath: "/tmp/store/DerivedData"),
            xcodeBuildServerPath: "/opt/homebrew/bin/xcode-build-server",
            buildRoot: nil
        )

        let args = XcodeSemanticIndexRunner.xcodebuildArguments(for: request)

        XCTAssertEqual(args.last, "build", "Semantic index must end with a build action")
        XCTAssertFalse(
            args.contains("clean"),
            "Semantic index must NOT clean build — incremental builds + merge keep the CPU cost low"
        )
        let buildIndex = try? XCTUnwrap(args.firstIndex(of: "build"))
        XCTAssertNotNil(buildIndex)
        XCTAssertTrue(args.contains("-project"))
        XCTAssertTrue(args.contains("/tmp/Example.xcodeproj"))
        XCTAssertTrue(args.contains("-derivedDataPath"))
    }

    func testXcodebuildArgumentsUseWorkspaceFlagForWorkspaces() {
        let request = XcodeSemanticIndexRunner.Request(
            workspaceURL: URL(fileURLWithPath: "/tmp/Example.xcworkspace"),
            scheme: "Lumi",
            configuration: "Debug",
            destinationQuery: "platform=macOS",
            storeDirectory: URL(fileURLWithPath: "/tmp/store"),
            derivedDataDirectory: URL(fileURLWithPath: "/tmp/store/DerivedData"),
            xcodeBuildServerPath: "/opt/homebrew/bin/xcode-build-server",
            buildRoot: nil
        )

        let args = XcodeSemanticIndexRunner.xcodebuildArguments(for: request)
        XCTAssertTrue(args.contains("-workspace"))
        XCTAssertFalse(args.contains("-project"))
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

    func testDiscoverBuildRootUsesDerivedDataRootWhenBuildFolderExistsDirectly() throws {
        let derivedData = FileManager.default.temporaryDirectory
            .appendingPathComponent("discover-build-root-direct-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: derivedData.appendingPathComponent("Build"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: derivedData) }

        XCTAssertEqual(
            URL(fileURLWithPath: XcodeSemanticIndexRunner.discoverBuildRoot(in: derivedData) ?? "").standardizedFileURL,
            derivedData.standardizedFileURL
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

    func testRunCommandCapturingOutputDrainsLargeStderrWithoutDeadlock() async throws {
        // Regression: `xcode-build-server parse` emits hundreds of KB to stderr on large projects.
        // The kernel pipe buffer is ~64KB, so if the parent waits for exit before draining the pipe,
        // the child blocks on write and the call deadlocks. Emit ~200KB to stderr and require the call
        // to complete and capture the full output. Pre-fix this test hangs indefinitely.
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture-large-stderr-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let line = String(repeating: "x", count: 49)
        let result = await XcodeSemanticIndexRunner.runCommandCapturingOutput(
            executablePath: "/bin/sh",
            arguments: ["-c", "for i in $(seq 1 5000); do echo \(line) 1>&2; done"],
            workingDirectory: tempDirectory
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertGreaterThan(result.output.utf8.count, 65_536)
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

    func testValidateCompileDatabaseRejectsMissingSchemeModule() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("compile-db-scheme-missing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let compileURL = tempDirectory.appendingPathComponent(".compile")
        try Data("""
        [
          {"module_name":"EditorSwiftPlugin","command":"swiftc -module-name EditorSwiftPlugin "}
        ]
        """.utf8).write(to: compileURL)

        let issue = XcodeSemanticIndexRunner.validateCompileDatabase(at: compileURL, scheme: "Lumi")
        XCTAssertNotNil(issue)
        XCTAssertTrue(issue?.contains("Lumi") == true)
    }

    func testValidateCompileDatabaseAcceptsSchemeModule() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("compile-db-scheme-present-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let compileURL = tempDirectory.appendingPathComponent(".compile")
        try Data("""
        [
          {"module_name":"Lumi","command":"swiftc -module-name Lumi "}
        ]
        """.utf8).write(to: compileURL)

        XCTAssertNil(XcodeSemanticIndexRunner.validateCompileDatabase(at: compileURL, scheme: "Lumi"))
    }
}
#endif
