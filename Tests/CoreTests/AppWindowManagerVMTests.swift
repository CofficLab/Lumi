#if canImport(XCTest)
import AppKit
import SwiftUI
import XCTest
@testable import Lumi

final class AppWindowManagerVMTests: XCTestCase {
    func testRootViewChatImageDetectionIsCaseInsensitive() {
        XCTAssertTrue(RootView<EmptyView>.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.PNG")))
        XCTAssertTrue(RootView<EmptyView>.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.heic")))
        XCTAssertFalse(RootView<EmptyView>.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.txt")))
    }

    func testPostOpenFileInEditorIncludesWindowId() throws {
        let expectedURL = URL(fileURLWithPath: "/tmp/Lumi.md")
        let expectedWindowId = UUID()
        let notification = expectation(description: "open file notification")
        var receivedURL: URL?
        var receivedWindowId: UUID?

        let observer = NotificationCenter.default.addObserver(
            forName: .openFileInEditor,
            object: nil,
            queue: nil
        ) { note in
            receivedURL = note.userInfo?["url"] as? URL
            receivedWindowId = note.userInfo?["windowId"] as? UUID
            notification.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        NotificationCenter.postOpenFileInEditor(url: expectedURL, windowId: expectedWindowId)
        wait(for: [notification], timeout: 1)

        XCTAssertEqual(receivedURL, expectedURL)
        XCTAssertEqual(receivedWindowId, expectedWindowId)
    }

    func testRestoredEditorStateDeduplicatesAndIncludesActiveFile() {
        let state = WindowContainer.restoredEditorState(
            openFilePaths: [
                "/tmp/Lumi/A.swift",
                "/tmp/Lumi/A.swift",
                "   ",
            ],
            activeFilePath: "/tmp/Lumi/B.swift"
        )

        XCTAssertEqual(
            state.openFiles.map(\.path),
            [
                "/tmp/Lumi/A.swift",
                "/tmp/Lumi/B.swift",
            ]
        )
        XCTAssertEqual(state.activeFile?.path, "/tmp/Lumi/B.swift")
    }

    func testEditorSessionStateFollowsTabOrderAndActiveFile() {
        let activeURL = URL(fileURLWithPath: "/tmp/Lumi/B.swift")
        let state = WindowContainer.editorSessionState(
            tabFileURLs: [
                URL(fileURLWithPath: "/tmp/Lumi/A.swift"),
                nil,
                activeURL,
            ],
            activeFile: activeURL
        )

        XCTAssertEqual(
            state.openFiles.map(\.path),
            [
                "/tmp/Lumi/A.swift",
                "/tmp/Lumi/B.swift",
            ]
        )
        XCTAssertEqual(state.activeFile, activeURL)
    }

    @MainActor
    func testProjectControllerDirectoryResolutionRejectsInvalidProjectPaths() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiProjectController-\(UUID().uuidString)", isDirectory: true)
        let projectURL = tempRoot.appendingPathComponent("Project", isDirectory: true)
        let fileURL = tempRoot.appendingPathComponent("file.txt", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(atPath: fileURL.path, contents: Data()))

        XCTAssertEqual(
            ProjectController.existingDirectoryURL(path: projectURL.path)?.path,
            projectURL.standardizedFileURL.path
        )
        XCTAssertEqual(
            ProjectController.existingDirectoryURL(path: "  \(projectURL.path)  ")?.path,
            projectURL.standardizedFileURL.path
        )
        XCTAssertNil(ProjectController.existingDirectoryURL(path: fileURL.path))
        XCTAssertNil(ProjectController.existingDirectoryURL(path: tempRoot.appendingPathComponent("Missing").path))
        XCTAssertNil(ProjectController.existingDirectoryURL(path: "   "))
    }

    @MainActor
    func testAssociateWindowIsIdempotentForCloseNotification() {
        let manager = AppWindowManagerVM()
        let window = NSWindow()
        let windowId = UUID()
        var closeCount = 0

        let observer = NotificationCenter.default.addObserver(
            forName: .windowClosed,
            object: nil,
            queue: nil
        ) { notification in
            if notification.object as? UUID == windowId {
                closeCount += 1
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        manager.associateWindow(window, with: windowId)
        manager.associateWindow(window, with: windowId)

        NotificationCenter.default.post(
            name: NSWindow.willCloseNotification,
            object: window
        )

        XCTAssertEqual(closeCount, 1)
    }

    @MainActor
    func testActivatePreferredWindowFallsBackToAssociatedWindow() {
        let manager = AppWindowManagerVM()
        let missingWindowId = UUID()
        let fallbackWindowId = UUID()
        let fallbackWindow = NSWindow()

        manager.setActiveWindow(missingWindowId)
        manager.associateWindow(fallbackWindow, with: fallbackWindowId)

        XCTAssertTrue(manager.activatePreferredWindow())
        XCTAssertEqual(manager.activeWindowId, fallbackWindowId)
    }

    @MainActor
    func testActivatePreferredWindowReturnsFalseWithoutAssociatedWindows() {
        let manager = AppWindowManagerVM()

        XCTAssertFalse(manager.activatePreferredWindow())
    }

    func testWindowIdsAreNotPersistedEmptyBeforeAnyWindowRegisters() {
        XCTAssertFalse(
            AppWindowManagerVM.shouldPersistWindowIds([], hasRegisteredWindow: false)
        )
    }

    func testWindowIdsCanPersistEmptyAfterAWindowRegistered() {
        XCTAssertTrue(
            AppWindowManagerVM.shouldPersistWindowIds([], hasRegisteredWindow: true)
        )
    }

    func testWindowIdsCanPersistNonEmptyBeforeRegistrationFlagUpdates() {
        XCTAssertTrue(
            AppWindowManagerVM.shouldPersistWindowIds([UUID()], hasRegisteredWindow: false)
        )
    }
}
#endif
