import ProviderToast
import XCTest
@testable import PluginToast

/// ToastCenter 的纯状态机契约（不依赖真实时钟）。
@MainActor
final class ToastCenterStateTests: XCTestCase {

    func testShowClearsActiveLoading() {
        let center = ToastCenter()
        center.showLoading(title: "Loading", detail: nil)

        center.show(LumiToast(title: "Done", style: .success))

        XCTAssertNil(center.currentLoading, "展示普通 toast 应清除 loading")
        XCTAssertEqual(center.currentToast?.title, "Done")
        center.dismiss()
    }

    func testShowLoadingClearsToastButPreservesError() {
        let center = ToastCenter()
        center.presentError(title: "Error", message: "boom")

        center.showLoading(title: "Loading", detail: "…")

        XCTAssertNil(center.currentToast)
        XCTAssertNotNil(center.currentLoading)
        XCTAssertEqual(center.currentError?.title, "Error", "loading 不应清除持久化错误")
        center.dismiss()
    }

    func testErrorAndToastCoexist() {
        let center = ToastCenter()
        center.presentError(title: "Pull failed", message: "divergent branches")
        center.show(LumiToast(title: "Retrying", style: .info))

        XCTAssertEqual(center.currentError?.title, "Pull failed")
        XCTAssertEqual(center.currentToast?.title, "Retrying")
        center.dismiss()
    }

    func testDismissErrorPreservesToast() {
        let center = ToastCenter()
        center.show(LumiToast(title: "Saved", style: .success))
        center.presentError(title: "Sync failed", message: "timeout")

        center.dismissError()

        XCTAssertNil(center.currentError)
        XCTAssertEqual(center.currentToast?.title, "Saved", "关闭错误不应影响当前 toast")
        center.dismiss()
    }

    func testPresentErrorReplacesPreviousError() {
        let center = ToastCenter()
        center.presentError(title: "First", message: "a")

        center.presentError(title: "Second", message: "b")

        XCTAssertEqual(center.currentError?.title, "Second")
        XCTAssertEqual(center.currentError?.message, "b")
        center.dismissError()
    }

    func testDismissClearsEveryState() {
        let center = ToastCenter()
        center.show(LumiToast(title: "T", style: .info))
        center.presentError(title: "E", message: "m")
        center.showLoading(title: "L", detail: nil)

        center.dismiss()

        XCTAssertNil(center.currentToast)
        XCTAssertNil(center.currentError)
        XCTAssertNil(center.currentLoading)
    }

    func testDismissAllClearsEveryState() {
        let center = ToastCenter()
        center.show(LumiToast(title: "T", style: .info))
        center.presentError(title: "E", message: "m")
        center.showLoading(title: "L", detail: nil)

        center.dismissAll()

        XCTAssertNil(center.currentToast)
        XCTAssertNil(center.currentError)
        XCTAssertNil(center.currentLoading)
    }

    func testErrorConvenienceWithoutDurationShowsPersistentError() {
        let center = ToastCenter()
        center.error("Sync failed", detail: "timeout")

        XCTAssertNil(center.currentToast)
        XCTAssertEqual(center.currentError?.title, "Sync failed")
        XCTAssertEqual(center.currentError?.message, "timeout")
        center.dismissError()
    }

    func testErrorConvenienceWithDurationShowsTransientToast() {
        let center = ToastCenter()
        center.error("Sync failed", detail: "timeout", duration: 1)

        XCTAssertNil(center.currentError)
        XCTAssertEqual(center.currentToast?.title, "Sync failed")
        XCTAssertEqual(center.currentToast?.style, .error)
        center.dismiss()
    }

    func testLoadingDetailIsOptional() {
        let center = ToastCenter()
        center.showLoading(title: "Just title", detail: nil)

        XCTAssertEqual(center.currentLoading?.title, "Just title")
        XCTAssertNil(center.currentLoading?.detail)
        center.dismissLoading()
    }
}
