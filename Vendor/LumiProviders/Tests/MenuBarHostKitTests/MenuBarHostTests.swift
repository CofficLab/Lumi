#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import MenuBarHostKit

@MainActor
@Suite struct MenuBarHostTests {
    @Test func installConfiguresStatusItemAndCreatesPopoverLazily() {
        let host = MenuBarHost()
        let configuration = MenuBarHostConfiguration(
            statusViewHeight: 20,
            accessibilityIdentifier: "test.menu-bar",
            accessibilityLabel: "Test menu bar"
        )

        host.install(statusView: AnyView(Text("Status")), configuration: configuration) {
            AnyView(Text("Popup"))
        }

        #expect(host.isInstalled)
        #expect(host.popover == nil)
        #expect(host.statusItem?.button?.accessibilityIdentifier() == "test.menu-bar")
        #expect(host.statusItem?.button?.accessibilityLabel() == "Test menu bar")
        #expect(host.statusHostingView?.hitTest(.zero) == nil)
        #expect(host.statusHostingView?.constraints.contains { $0.firstAttribute == .height && $0.constant == 20 } == true)

        let popover = host.makePopoverIfNeeded()
        #expect(popover?.behavior == .transient)
        #expect(host.makePopoverIfNeeded() === popover)
        host.cleanup()
    }

    @Test func repeatedInstallKeepsOriginalStatusItem() {
        let host = MenuBarHost()
        host.install(statusView: AnyView(Text("First"))) { AnyView(Text("First popup")) }
        let originalItem = host.statusItem

        host.install(statusView: AnyView(Text("Second"))) { AnyView(Text("Second popup")) }

        #expect(host.statusItem === originalItem)
        host.cleanup()
    }

    @Test func fixedAndConstrainedSizingAreApplied() {
        let host = MenuBarHost()
        host.install(
            statusView: AnyView(Text("Status")),
            configuration: MenuBarHostConfiguration(
                popoverSizing: .fixedSize(NSSize(width: 640, height: 760))
            )
        ) { AnyView(Text("Popup")) }

        #expect(host.makePopoverIfNeeded()?.contentSize == NSSize(width: 640, height: 760))
        host.cleanup()

        host.install(
            statusView: AnyView(Text("Status")),
            configuration: MenuBarHostConfiguration(
                popoverSizing: .fixedWidth(300, maximumHeight: 800)
            )
        ) { AnyView(Text("Popup").frame(height: 900)) }

        #expect(host.makePopoverIfNeeded()?.contentSize.width == 300)
        #expect((host.popover?.contentSize.height ?? 0) <= 800)
        host.cleanup()
        #expect(!host.isInstalled)
        #expect(host.popover == nil)
    }
}
#endif
