import KernelCore
import ProviderToast
import XCTest
@testable import PluginToast

@MainActor
final class ToastSuperPluginTests: XCTestCase {
    func testToastPluginReplacesTheDefaultProvider() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ToastProviding).self, DefaultToastProviding())

        let plugin = ToastSuperPlugin()
        try plugin.onBoot(kernel: kernel)

        XCTAssertTrue(kernel.resolveProvider((any ToastProviding).self) === plugin.center)
    }

    func testToastPluginMountsOverlayOnRootView() throws {
        let kernel = KernelCoreContainer()
        var isMounted = false

        let plugin = ToastSuperPlugin(
            overlayInstaller: { _, _ in isMounted = true },
            overlayUninstaller: { _ in isMounted = false }
        )
        try plugin.onBoot(kernel: kernel)
        XCTAssertTrue(isMounted)

        try plugin.onShutdown(kernel: kernel)
        XCTAssertFalse(isMounted)
    }

    func testDismissClearsTheCurrentToast() {
        let center = ToastCenter()
        center.show(LumiToast(title: "Saved", style: .success))
        XCTAssertEqual(center.currentToast?.title, "Saved")
        center.dismiss()
        XCTAssertNil(center.currentToast)
    }

    func testPersistentErrorRequiresExplicitDismissal() {
        let center = ToastCenter()
        center.presentError(title: "Pull failed", message: "hint: divergent branches")

        XCTAssertEqual(center.currentError?.title, "Pull failed")
        XCTAssertEqual(center.currentError?.message, "hint: divergent branches")

        center.dismissError()

        XCTAssertNil(center.currentError)
    }
}
