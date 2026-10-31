import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import ComputerUsePlugin

/// 目标窗口提示遮罩的行为约定。
///
/// 遮罩要解决的是「用户看到界面被改动，却不知道是 Lumi 干的」这一缺口。
/// 它必须同时满足三组不变量：
///
/// 1. **位置正确**：Quartz 与 AppKit 坐标系的换算必须按窗口所在屏幕翻转，
///    否则遮罩会挂在错误的位置；
/// 2. **强度恰当**：AX 路径是后台操作，不能挡住用户的内容；
///    原生输入路径独占桌面，才允许更强的宣告；
/// 3. **及时退场**：操作结束后不能立刻消失（用户来不及察觉），
///    也不能赖着不走（持续干扰）。
@Suite("Computer Use 目标窗口提示遮罩")
struct ComputerUseTargetOverlayTests {
    // MARK: - 坐标转换

    @Test("Quartz 矩形按所在屏幕翻转为 AppKit 矩形")
    func quartzRectConvertsToAppKitUsingHostingScreen() {
        // 主屏在 Quartz 中是 (0,0,1920,1080)；AppKit 中 y 向上。
        // 位于 (300,388) 尺寸 500x392 的窗口，AppKit 的 y 应为
        // 1080 - 388 - 392 = 300。
        let quartz = CGRect(x: 300, y: 388, width: 500, height: 392)
        let converted = ScreenCoordinateConverter.appKitRect(fromQuartz: quartz)
        let expected = try? #require(converted)
        #expect(expected?.minX == 300)
        #expect(expected?.minY == 300)
        #expect(expected?.width == 500)
        #expect(expected?.height == 392)
    }

    @Test("空矩形与退化尺寸不产生遮罩矩形")
    func degenerateRectanglesAreRejected() {
        #expect(ScreenCoordinateConverter.appKitRect(fromQuartz: .zero) == nil)
        #expect(ScreenCoordinateConverter.appKitRect(fromQuartz: CGRect(x: 0, y: 0, width: 0, height: 100)) == nil)
        #expect(ScreenCoordinateConverter.appKitRect(fromQuartz: CGRect(x: 0, y: 0, width: 100, height: 0)) == nil)
    }

    @Test("落在所有屏幕之外的窗口无法定位")
    func rectOutsideEveryScreenIsRejected() {
        // 远超桌面边界的矩形不会与任何屏幕相交，必须返回 nil，
        // 否则遮罩会画到看不见的地方。
        let faraway = CGRect(x: 99_000, y: 99_000, width: 400, height: 300)
        #expect(ScreenCoordinateConverter.appKitRect(fromQuartz: faraway) == nil)
    }

    @Test("换算后矩形的宽高与原 Quartz 矩形一致")
    func convertedRectPreservesSize() {
        let quartz = CGRect(x: 120, y: 200, width: 640, height: 480)
        let converted = try? #require(ScreenCoordinateConverter.appKitRect(fromQuartz: quartz))
        #expect(converted?.width == quartz.width)
        #expect(converted?.height == quartz.height)
    }

    // MARK: - 强度策略

    @Test("AX 路径使用克制的强度，原生输入路径使用强宣告强度")
    func intensitiesDifferBetweenExecutionPaths() {
        let subtle = ComputerUseTargetOverlayIntensity.subtle
        let blocking = ComputerUseTargetOverlayIntensity.blocking

        // AX 路径是后台操作，遮罩不能挡住用户正在读的内容。
        #expect(subtle.tintOpacity < blocking.tintOpacity)
        #expect(subtle.tintOpacity <= 0.1)
        // 原生输入路径真正接管了鼠标键盘，需要明确宣告。
        #expect(blocking.tintOpacity >= 0.2)
    }

    @Test("两种强度的角标文案不同")
    func badgeTextsDistinguishControlPaths() {
        let subtle = ComputerUseTargetOverlayIntensity.subtle
        let blocking = ComputerUseTargetOverlayIntensity.blocking

        let subtleText = subtle.badgeText(applicationName: "Notes")
        let blockingText = blocking.badgeText(applicationName: "Notes")

        #expect(subtleText != blockingText)
        #expect(subtleText.contains("Notes"))
        #expect(blockingText.contains("Notes"))
    }

    // MARK: - 淡出时机

    @Test("遮罩在操作结束后停留一段时间再淡出")
    func overlayLingersBeforeFadingOut() {
        // 立即消失会让提示一闪而过，用户根本没看见；
        // 但停留必须是有限时间，不能持续干扰。
        #expect(ComputerUseTargetOverlayController.lingerDuration > 0)
        #expect(ComputerUseTargetOverlayController.lingerDuration <= 5)
    }

    @Test("跟随窗口的轮询间隔足够及时且不密集")
    func followIntervalIsResponsiveButNotBusy() {
        let interval = ComputerUseTargetOverlayController.followInterval
        #expect(interval <= .milliseconds(500))
        #expect(interval >= .milliseconds(50))
    }

    @Test("遮罩目标描述可比较")
    func overlayTargetIsEquatable() {
        let rect = CGRect(x: 10, y: 20, width: 300, height: 200)
        let first = ComputerUseTargetOverlayController.Target(
            quartzRect: rect,
            applicationName: "Notes",
            intensity: .subtle
        )
        let second = ComputerUseTargetOverlayController.Target(
            quartzRect: rect,
            applicationName: "Notes",
            intensity: .subtle
        )
        let different = ComputerUseTargetOverlayController.Target(
            quartzRect: rect,
            applicationName: "Notes",
            intensity: .blocking
        )
        #expect(first == second)
        #expect(first != different)
    }

    // MARK: - 面板安全属性

    @MainActor
    @Test("遮罩面板不拦截鼠标事件也不参与焦点")
    func overlayPanelIgnoresMouseAndFocus() {
        let panel = ComputerUseTargetOverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200))

        // ignoresMouseEvents 必须为 true：原生输入路径靠 CGEvent 合成点击，
        // 遮罩一旦吞掉事件，Lumi 的点击会打在遮罩上而不是目标应用上。
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        // 层级必须高于普通应用窗口，否则目标应用在前台时遮罩被盖住。
        #expect(panel.level == .screenSaver)
    }
}
