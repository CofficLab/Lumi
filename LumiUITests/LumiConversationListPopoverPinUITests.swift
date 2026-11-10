import XCTest

/// 工具栏对话列表 popover 的图钉行为。
///
/// 图钉钉的是 **popover**（浮层常驻），不是会话置顶：
/// - 钉住后点击应用内其它区域、切换前台应用，浮层都不能收起；
/// - 取消钉住后恢复默认的点击外部收起行为。
///
/// ## 夹具
///
/// `--lumi-ui-testing-message-list-standard` 会植入两个会话，
/// `--lumi-ui-testing-isolated-storage` 把数据写到临时目录。
final class LumiConversationListPopoverPinUITests: LumiUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            "--lumi-ui-testing-message-list-standard",
            "--lumi-ui-testing-isolated-storage",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    func testPinKeepsPopoverOpenThenUnpinRestoresTransientBehavior() throws {
        // 工具栏按钮继承根容器的 accessibilityIdentifier（root.main），
        // 因此这里按稳定的无障碍 label "Chats" 定位，而不是 identifier。
        let toolbarButton = element(anyLabelOf: ["Chats"])
        XCTAssertTrue(toolbarButton.waitForExistence(timeout: 30), "工具栏对话列表按钮未出现")

        toolbarButton.click()

        let pinButton = element(anyLabelOf: ["Pin", "Unpin"])
        XCTAssertTrue(pinButton.waitForExistence(timeout: 10), "popover 内的图钉按钮未出现")

        // 1. 钉住后点击应用内其它区域，浮层仍在。
        pinButton.click()
        attachScreenshot(named: "01-pinned")
        clickInsideMainWindow()
        XCTAssertTrue(pinButton.waitForExistence(timeout: 3), "钉住后点击应用内其它区域，popover 不应收起")
        attachScreenshot(named: "02-pinned-after-inside-click")

        // 2. 钉住后切换到前台应用（Finder），浮层仍在。
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        XCTAssertTrue(pinButton.waitForExistence(timeout: 3), "钉住后切换前台应用，popover 不应收起")
        attachScreenshot(named: "03-pinned-after-app-switch")

        // 3. 回到 Lumi，取消钉住；再点击外部，浮层恢复临时行为并收起。
        app.activate()
        XCTAssertTrue(pinButton.waitForExistence(timeout: 5), "回到 Lumi 后 popover 应仍在")
        pinButton.click()
        clickInsideMainWindow()
        XCTAssertFalse(pinButton.waitForExistence(timeout: 3), "取消钉住后点击外部，popover 应恢复收起")
        attachScreenshot(named: "04-unpinned-and-dismissed")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 点击主窗口内一个远离工具栏按钮的位置（底部中间），用于验证外部点击。
    private func clickInsideMainWindow() {
        let window = app.windows
            .containing(.any, identifier: "root.main")
            .firstMatch
        XCTAssertTrue(window.exists, "主窗口不存在")
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).click()
    }
}
