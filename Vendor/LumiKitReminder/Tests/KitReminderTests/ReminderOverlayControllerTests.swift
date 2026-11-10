import Foundation
import Testing
@testable import KitReminder

/// 遮罩控制器的时序行为。
///
/// 这里验证的是**真实窗口路径**曾经缺失的保证：
///
/// 早期实现在淡出回调里用弱引用访问控制器（`self?.fadeOutAndClose()`），
/// 而插件用临时对象创建控制器，表达式求值完控制器即被释放，
/// 于是回调体永不执行——全屏遮罩永久滞留屏幕，且无法点击关闭。
///
/// 由于真实 `NSPanel` 在测试进程里难以断言，控制器提供了注入窗口工厂的
/// 初始化入口，测试用替身窗口验证同一套时序逻辑。
@MainActor
struct ReminderOverlayControllerTests {

    /// 记录调用的替身窗口。
    private final class SpyWindow: ReminderOverlayWindowing {
        private(set) var isVisible = false
        private(set) var alphaValues: [CGFloat] = []
        private(set) var showCount = 0
        private(set) var hideCount = 0
        private(set) var tearDownCount = 0

        func setAlpha(
            _ alpha: CGFloat,
            animated: Bool,
            duration: TimeInterval,
            completion: (() -> Void)?
        ) {
            alphaValues.append(alpha)
            if animated {
                completion?()
            } else {
                completion?()
            }
        }

        func show() {
            isVisible = true
            showCount += 1
        }

        func hide() {
            isVisible = false
            hideCount += 1
        }

        func tearDown() {
            tearDownCount += 1
        }
    }

    /// 构造一个注入替身窗口的控制器。
    private func makeController(
        displayDuration: TimeInterval = 0.2,
        windows: @escaping @MainActor () -> [SpyWindow]
    ) -> ReminderOverlayController {
        ReminderOverlayController(
            displayDuration: displayDuration,
            windowFactory: { _ in windows() }
        )
    }

    @Test("淡出后遮罩不再可见")
    func overlayFadesOutAfterDisplayDuration() async throws {
        let spy = SpyWindow()
        let controller = makeController { [spy] in [spy] }

        controller.showAndFadeOut()
        #expect(controller.isVisible)

        try await Task.sleep(for: .milliseconds(600))

        #expect(!controller.isVisible)
    }

    @Test("淡出后窗口被隐藏并释放")
    func overlayWindowIsTornDownAfterFadeOut() async throws {
        let spy = SpyWindow()
        let controller = makeController { [spy] in [spy] }

        controller.showAndFadeOut()
        try await Task.sleep(for: .milliseconds(600))

        #expect(spy.hideCount >= 1)
        #expect(spy.tearDownCount >= 1)
    }

    @Test("淡出后不透明度归零")
    func overlayAlphaReachesZero() async throws {
        let spy = SpyWindow()
        let controller = makeController { [spy] in [spy] }

        controller.showAndFadeOut()
        try await Task.sleep(for: .milliseconds(600))

        #expect(spy.alphaValues.contains(0))
    }

    @Test("展示期间控制器被强引用，淡出回调必定执行")
    func controllerStaysAliveDuringDisplay() async throws {
        let spy = SpyWindow()
        weak var weakController: ReminderOverlayController?

        // 用立即执行并丢弃结果的闭包创建控制器，
        // 确保测试自身**不持有**强引用——否则局部变量会把控制器续命，
        // 断言就测不到「展示期间是否有人持有控制器」这件事。
        let start: @MainActor () -> Void = {
            let controller = ReminderOverlayController(
                displayDuration: 0.3,
                windowFactory: { _ in [spy] }
            )
            weakController = controller
            controller.showAndFadeOut()
        }
        start()

        // 展示期间控制器必须仍然存活：
        // 淡出回调依赖它，若此时被释放，回调将永不执行，
        // 遮罩会永久滞留屏幕。
        try await Task.sleep(for: .milliseconds(100))
        #expect(weakController != nil)

        try await Task.sleep(for: .milliseconds(600))

        // 淡出完成后不再需要自持有，可以释放。
        #expect(weakController == nil)
    }

    @Test("手动关闭后遮罩立即消失")
    func manualDismissClosesOverlayImmediately() {
        let spy = SpyWindow()
        let controller = makeController(displayDuration: 60) { [spy] in [spy] }

        controller.showAndFadeOut()
        #expect(controller.isVisible)

        controller.dismissAll()

        #expect(!controller.isVisible)
        #expect(spy.hideCount >= 1)
        #expect(spy.tearDownCount >= 1)
    }

    @Test("手动关闭会取消待执行的自动淡出")
    func manualDismissCancelsPendingFadeOut() async throws {
        let spy = SpyWindow()
        let controller = makeController(displayDuration: 0.2) { [spy] in [spy] }

        controller.showAndFadeOut()
        controller.dismissAll()

        try await Task.sleep(for: .milliseconds(500))

        // 自动淡出不应再对已关闭的窗口重复操作。
        #expect(spy.tearDownCount == 1)
    }

    @Test("重复展示不叠加窗口")
    func repeatedShowDoesNotStackWindows() {
        let spy = SpyWindow()
        let controller = makeController(displayDuration: 60) { [spy] in [spy] }

        controller.showAndFadeOut()
        controller.showAndFadeOut()

        // 第二次展示前应先关闭第一批窗口。
        #expect(spy.tearDownCount == 1)
        #expect(controller.isVisible)
    }

    @Test("展示期间调用方不再持有控制器，淡出依然执行")
    func fadeOutRunsWithoutExternalOwner() async throws {
        let spy = SpyWindow()

        // 模拟插件的真实用法：临时对象创建控制器后立即丢弃引用。
        makeController(displayDuration: 0.2) { [spy] in [spy] }.showAndFadeOut()

        try await Task.sleep(for: .milliseconds(600))

        #expect(spy.alphaValues.contains(0))
        #expect(spy.tearDownCount >= 1)
    }
}
