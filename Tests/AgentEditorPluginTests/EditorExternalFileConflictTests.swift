#if canImport(XCTest)
import AppKit
import XCTest
@testable import Lumi

@MainActor
final class EditorExternalFileConflictTests: XCTestCase {

    func testExternalFileConflictCanKeepEditorVersion() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("conflict.txt")
        try "disk v1\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = EditorState()
        state.loadFile(from: fileURL)
        try await waitFor { state.content?.string == "disk v1\n" }

        state.content = NSTextStorage(string: "editor local\n")
        state.hasUnsavedChanges = true
        state.saveState = .editing

        try "disk v2\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try await waitFor { state.hasExternalFileConflict }

        XCTAssertEqual(state.saveState, .conflict(EditorStatusMessageCatalog.externalFileChangedOnDisk()))

        state.keepEditorVersionForExternalConflict()

        XCTAssertFalse(state.hasExternalFileConflict)
        XCTAssertEqual(state.content?.string, "editor local\n")
        XCTAssertTrue(state.hasUnsavedChanges)
        XCTAssertEqual(state.saveState, .editing)
        XCTAssertTrue(state.activeSession.isDirty)
        XCTAssertEqual(state.activeSession.fileURL, fileURL)
    }

    func testExternalFileConflictCanReloadFromDisk() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("reload.txt")
        try "disk v1\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = EditorState()
        state.loadFile(from: fileURL)
        try await waitFor { state.content?.string == "disk v1\n" }

        state.content = NSTextStorage(string: "editor local\n")
        state.hasUnsavedChanges = true
        state.saveState = .editing

        try "disk v2\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try await waitFor { state.hasExternalFileConflict }

        state.reloadExternalFileConflict()

        XCTAssertFalse(state.hasExternalFileConflict)
        XCTAssertEqual(state.content?.string, "disk v2\n")
        XCTAssertFalse(state.hasUnsavedChanges)
        XCTAssertEqual(state.saveState, .idle)
        XCTAssertFalse(state.activeSession.isDirty)
        XCTAssertEqual(state.activeSession.fileURL, fileURL)
    }

    private func waitFor(
        timeout: TimeInterval = 3.0,
        poll: UInt64 = 100_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: poll)
        }
        XCTFail("Condition not met within timeout")
    }
}

#endif
