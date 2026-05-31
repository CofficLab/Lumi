#if canImport(XCTest)
import AppKit
import XCTest
@testable import Lumi

final class AppWindowManagerVMTests: XCTestCase {
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
