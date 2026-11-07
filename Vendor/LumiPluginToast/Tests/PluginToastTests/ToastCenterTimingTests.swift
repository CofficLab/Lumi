import ProviderToast
import XCTest
@testable import PluginToast

/// ToastCenter 的时序契约：自动消失、替换式节流与计时器取消。
///
/// 这些测试使用真实时钟与短时长，验证 README 宣称的核心行为：
/// 「默认 3 秒自动消失」「高频消息刷新当前 toast 而非堆叠」。
@MainActor
final class ToastCenterTimingTests: XCTestCase {

    // MARK: - 自动消失

    func testToastWithoutDurationAutoDismissesAfterDefaultInterval() async {
        let center = ToastCenter()
        center.show(LumiToast(title: "Default", style: .info))

        // 默认时长是 3 秒：2 秒时仍应展示。
        try? await Task.sleep(for: .seconds(2))
        XCTAssertEqual(center.currentToast?.title, "Default", "默认时长 toast 在 2 秒时不应消失")

        // 3 秒过后应自动消失（留出调度余量）。
        let dismissed = await waitUntil(timeout: 2.5) { center.currentToast == nil }
        XCTAssertTrue(dismissed, "默认时长的 toast 应在约 3 秒后自动消失")
    }

    func testToastWithCustomDurationAutoDismisses() async {
        let center = ToastCenter()
        center.show(LumiToast(title: "Quick", style: .info, duration: 0.2))

        XCTAssertEqual(center.currentToast?.title, "Quick")
        let dismissed = await waitUntil(timeout: 2) { center.currentToast == nil }
        XCTAssertTrue(dismissed, "自定义时长的 toast 应按时自动消失")
    }

    func testZeroDurationToastDismissesImmediately() async {
        let center = ToastCenter()
        center.show(LumiToast(title: "Zero", style: .info, duration: 0))

        let dismissed = await waitUntil(timeout: 1) { center.currentToast == nil }
        XCTAssertTrue(dismissed, "零时长的 toast 应近乎立即消失")
    }

    // MARK: - 替换式节流

    func testShowingNewToastCancelsPendingDismissalOfPrevious() async {
        let center = ToastCenter()
        center.show(LumiToast(title: "First", style: .info, duration: 0.15))
        try? await Task.sleep(for: .milliseconds(50))

        // 第一条尚未到期时被替换，其消失计时器必须被取消。
        center.show(LumiToast(title: "Second", style: .info, duration: 10))

        // 等待超过第一条原本的 150ms 时长：若旧计时器未被取消，toast 会被错误清掉。
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(center.currentToast?.title, "Second", "新 toast 必须取消前一条的消失计时器")
        center.dismiss()
    }

    func testRefreshingSameToastRestartsDismissalTimer() async {
        let center = ToastCenter()
        center.show(LumiToast(title: "Sync", style: .info, duration: 0.3))
        try? await Task.sleep(for: .milliseconds(150))

        // 高频刷新：同样的 toast 再次出现，应重新计时而非沿用旧计时器。
        center.show(LumiToast(title: "Sync", style: .info, duration: 0.3))
        try? await Task.sleep(for: .milliseconds(200))

        // 距首次展示已 350ms > 300ms；若沿用旧计时器此刻已被清掉。
        XCTAssertEqual(center.currentToast?.title, "Sync", "刷新应取消旧计时器并重新计时")

        let dismissed = await waitUntil(timeout: 1) { center.currentToast == nil }
        XCTAssertTrue(dismissed, "刷新后的 toast 应按新计时器自动消失")
    }

    // MARK: - 加载 / 错误状态与 toast 计时的独立性

    func testShowLoadingCancelsToastDismissalTimer() async {
        let center = ToastCenter()
        center.show(LumiToast(title: "Saving", style: .info, duration: 0.2))
        center.showLoading(title: "Working", detail: "Please wait")

        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertNil(center.currentToast, "toast 应被 loading 替换")
        XCTAssertEqual(
            center.currentLoading?.title,
            "Working",
            "loading 不应被 toast 的消失计时器连带清除"
        )
        center.dismissLoading()
    }

    func testPersistentErrorOutlivesAutoDismissingToast() async {
        let center = ToastCenter()
        center.presentError(title: "Pull failed", message: "divergent branches")
        center.show(LumiToast(title: "Retrying", style: .info, duration: 0.2))

        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertNil(center.currentToast, "toast 应自动消失")
        XCTAssertEqual(
            center.currentError?.title,
            "Pull failed",
            "持久化错误不应随 toast 自动消失"
        )
        center.dismissError()
    }

    // MARK: - Helpers

    /// 轮询等待条件成立；超时返回 false。
    private func waitUntil(
        timeout: TimeInterval,
        _ condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }
}
