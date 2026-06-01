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
