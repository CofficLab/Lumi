import XCTest
@testable import PluginToast
import KernelCore
import ProviderToast

@MainActor
final class ToastCenterAdditionalTests: XCTestCase {
    func testShowWithCustomDuration() {
        let center = ToastCenter()
        let toast = LumiToast(title: "Custom", style: .info, duration: 1)
        center.show(toast)
        XCTAssertEqual(center.currentToast?.title, "Custom")
        center.dismiss()
    }

    func testShowReplacesPreviousToast() {
        let center = ToastCenter()
        center.show(LumiToast(title: "First", style: .success))
        center.show(LumiToast(title: "Second", style: .warning))
        XCTAssertEqual(center.currentToast?.title, "Second")
        center.dismiss()
    }

    func testLoadingReplacesToastAndCanBeDismissed() {
        let center = ToastCenter()
        center.show(LumiToast(title: "First", style: .info))

        center.showLoading(title: "Loading", detail: "Preparing")

        XCTAssertNil(center.currentToast)
        XCTAssertEqual(center.currentLoading?.title, "Loading")
        XCTAssertEqual(center.currentLoading?.detail, "Preparing")

        center.dismissLoading()
        XCTAssertNil(center.currentLoading)
    }
}

@MainActor
final class ToastSuperPluginLifecycleTests: XCTestCase {
    func testOnRegisterNoop() throws {
        let kernel = KernelCoreContainer()
        let plugin = ToastSuperPlugin()
        try plugin.onRegister(kernel: kernel)
        try plugin.onUnregister(kernel: kernel)
    }

    func testOnBootWithoutRootView() throws {
        let kernel = KernelCoreContainer()
        let plugin = ToastSuperPlugin()
        try plugin.onBoot(kernel: kernel)
        // ToastProviding should still be registered even without RootViewProviding.
        XCTAssertNotNil(kernel.resolveProvider((any ToastProviding).self))
    }

    func testOnShutdownNoop() throws {
        let kernel = KernelCoreContainer()
        let plugin = ToastSuperPlugin()
        try plugin.onShutdown(kernel: kernel)
    }
}
