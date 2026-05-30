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
}
#endif
