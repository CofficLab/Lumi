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

    /// 独立于生产实现地，从 `NSScreen` 重新推导一个 Quartz 矩形对应的 AppKit 矩形。
    ///
    /// ## 为什么必须重新推导
    ///
    /// 屏幕尺寸**随机器而变**：Retina 缩放、分辨率差异、多屏布局都会改变
    /// 主屏的点数尺寸。把「主屏是 1920x1080」写进断言，等于假设测试只在
    /// 某一种显示器上成立 —— 在 1710x1112 的机器上必然失败，而失败信息
    /// （`expected?.minY == 300` 却得到 332）完全看不出是**环境差异**，
    /// 很容易被误判成生产代码的换算缺陷。
    ///
    /// 这里用「窗口所在屏幕的实际几何」重算一遍期望值：断言的仍然是
    /// 同一条语义 —— **翻转必须锚定在窗口所在的那块屏幕上** ——
    /// 而不是某个具体分辨率下的具体数值。
    private func expectedAppKitRect(forQuartz quartz: CGRect) -> CGRect? {
        for screen in NSScreen.screens {
            let frame = screen.frame
            // 屏幕在 Quartz 坐标里的顶边（AppKit 原点在左下，故翻转）。
            let screenQuartzTop = frame.maxY - frame.height
            let screenQuartz = CGRect(
                x: frame.minX,
                y: screenQuartzTop,
                width: frame.width,
                height: frame.height
            )
            guard quartz.intersects(screenQuartz) else { continue }
            // 窗口顶边相对该屏幕顶部的偏移，换算回 AppKit 的 y。
            let topOffsetInQuartz = quartz.minY - screenQuartzTop
            return CGRect(
                x: quartz.minX,
                y: frame.maxY - topOffsetInQuartz - quartz.height,
                width: quartz.width,
                height: quartz.height
            )
        }
        return nil
    }

    /// 取一个落在主屏内、且尺寸稳定的窗口矩形。
    ///
    /// - Important: 位置按**实际屏幕尺寸**推算，不写死像素坐标 ——
    ///   否则小屏机器上矩形会落到屏幕外，`intersects` 判定会失真。
    private func sampleRectInMainScreen() throws -> CGRect {
        let screen = try #require(NSScreen.main, "当前环境没有主屏")
        let frame = screen.frame
        let width = min(500, frame.width - 100)
        let height = min(392, frame.height - 200)
        return CGRect(
            x: frame.minX + 300,
            y: frame.minY + 388,
            width: width,
            height: height
        )
    }

    @Test("Quartz 矩形按所在屏幕翻转为 AppKit 矩形")
    func quartzRectConvertsToAppKitUsingHostingScreen() throws {
        let quartz = try sampleRectInMainScreen()
        let converted = ScreenCoordinateConverter.appKitRect(fromQuartz: quartz)
        let expected = try #require(converted)
        let reference = try #require(expectedAppKitRect(forQuartz: quartz))

        #expect(expected.minX == reference.minX)
        #expect(expected.minY == reference.minY)
        #expect(expected.width == quartz.width)
        #expect(expected.height == quartz.height)

        // 翻转语义的核心不变量：窗口顶边在 AppKit 坐标里，
        // 等于「所在屏幕顶边」减去「窗口顶边到屏幕顶边的距离」。
        //
        // - Note: 这条不变量是「按所在屏幕翻转」与「按主屏高度翻转」
        //   的分界 —— 多屏且副屏在主屏上方时，两者结果不同。
        let screen = try #require(NSScreen.screens.first { screen in
            let frame = screen.frame
            let screenQuartz = CGRect(
                x: frame.minX,
                y: frame.maxY - frame.height,
                width: frame.width,
                height: frame.height
            )
            return quartz.intersects(screenQuartz)
        })
        let screenQuartzTop = screen.frame.maxY - screen.frame.height
        let expectedTop = screen.frame.maxY - (quartz.minY - screenQuartzTop)
        #expect(expected.maxY == expectedTop)
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
    func convertedRectPreservesSize() throws {
        let screen = try #require(NSScreen.main, "当前环境没有主屏")
        let frame = screen.frame
        // 尺寸按实际屏幕裁剪，保证矩形仍落在屏内（否则换算会返回 nil）。
        let quartz = CGRect(
            x: frame.minX + 120,
            y: frame.minY + 200,
            width: min(640, frame.width - 200),
            height: min(480, frame.height - 300)
        )
        let converted = try #require(ScreenCoordinateConverter.appKitRect(fromQuartz: quartz))
        #expect(converted.width == quartz.width)
        #expect(converted.height == quartz.height)
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

    // MARK: - 遮挡关系刷新

    @MainActor
    @Test("目标矩形不变时仍重算可见区域")
    func unchangedTargetStillRefreshesVisibleRegions() throws {
        let controller = ComputerUseTargetOverlayController.shared
        let quartz = try sampleRectInMainScreen()
        let frame = try #require(ScreenCoordinateConverter.appKitRect(fromQuartz: quartz))

        var movedTo: [CGRect] = []
        var refreshed: [CGRect] = []
        controller.follow(
            quartzRect: quartz,
            currentPanelFrame: frame,
            setPanelFrame: { movedTo.append($0) },
            refreshVisibleRegions: { refreshed.append($0) }
        )

        // 目标窗口不动时面板不必移动，但遮挡它的其他窗口可能已经变了，
        // 可见区域仍必须重算——否则遮罩会一直盖在遮挡者身上。
        #expect(movedTo.isEmpty)
        #expect(refreshed == [quartz])
    }

    @MainActor
    @Test("目标矩形变化时移动面板并重算可见区域")
    func changedTargetMovesPanelAndRefreshes() throws {
        let controller = ComputerUseTargetOverlayController.shared
        let quartz = try sampleRectInMainScreen()
        let frame = try #require(ScreenCoordinateConverter.appKitRect(fromQuartz: quartz))
        let slightlyDifferentFrame = frame.offsetBy(dx: 10, dy: 10)

        var movedTo: [CGRect] = []
        var refreshed: [CGRect] = []
        controller.follow(
            quartzRect: quartz,
            currentPanelFrame: slightlyDifferentFrame,
            setPanelFrame: { movedTo.append($0) },
            refreshVisibleRegions: { refreshed.append($0) }
        )

        #expect(movedTo == [frame])
        #expect(refreshed == [quartz])
    }

    @Test("遮罩目标描述可比较")
    func overlayTargetIsEquatable() {
        let rect = CGRect(x: 10, y: 20, width: 300, height: 200)
        let first = ComputerUseTargetOverlayController.Target(
            quartzRect: rect,
            applicationName: "Notes",
            intensity: .subtle,
            windowID: 1,
            processIdentifier: 100
        )
        let second = ComputerUseTargetOverlayController.Target(
            quartzRect: rect,
            applicationName: "Notes",
            intensity: .subtle,
            windowID: 1,
            processIdentifier: 100
        )
        let different = ComputerUseTargetOverlayController.Target(
            quartzRect: rect,
            applicationName: "Notes",
            intensity: .blocking,
            windowID: 1,
            processIdentifier: 100
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
