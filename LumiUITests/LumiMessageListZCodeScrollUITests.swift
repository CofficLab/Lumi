import XCTest
import AppKit

/// V4（ZCode）滚动语义的 UI 测试。
///
/// ## 要守住的语义
///
/// - 用户上滚超过 48px 后**脱离跟随**（detached）；
/// - 流式增量、异步测高、resize、终态折叠都**不得**把用户拽回底部；
/// - 用户滚回 48px 内**恢复跟随**；
/// - 「回到底部」按钮只在脱离跟随时出现，点击后恢复跟随并钉底。
///
/// ## 为什么用 48
///
/// 基准是 ZCode 3.15.1 的 `packages/ui/src/v4/timelineScrollAnchor.ts`：
/// `max(0, contentHeight - viewportHeight - scrollTop) <= 48` 视为底部。
///
/// - Important: V3 的 `BottomEdgeEvaluator` 用的是 enter 24 / leave 96，
///   两套阈值互不影响。
final class LumiMessageListZCodeScrollUITests: LumiUITestCase {
    /// 遮罩的稳定标识符。
    private let maskIdentifier = "lumi.message-list.loading-mask"

    /// 遮罩必须在此时间内消失。
    private let maskBudget: TimeInterval = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 全局 UI 测试开关：夹具在缺少它时**拒绝启动**。
            "--lumi-ui-testing",
            "--lumi-ui-testing-message-list-zcode",
            "--lumi-ui-testing-isolated-storage",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Cases

    /// 长列表会话必须能加载完成（遮罩消失），否则后续滚动无从谈起。
    func testScrollFixtureLoads() throws {
        switchConversation(to: MessageListZCodeUITestTitles.scroll)
        switchToVerbosity(.zcode)

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "长列表会话的首屏遮罩在 \(Int(maskBudget))s 内未消失")
    }

    /// 用户上滚后，「回到底部」按钮必须出现。
    ///
    /// - Important: 按钮的出现是「已脱离跟随」的**可观测证据**。
    ///   单纯检查滚动位置会受动画与布局时序影响。
    func testBackToBottomButtonAppearsAfterUserScrollUp() throws {
        try prepareScrollFixture()

        let backToBottom = element(identifier: "lumi.message.zcode.back-to-bottom")
        XCTAssertTrue(
            backToBottom.waitForExistence(timeout: 10),
            "上滚后「回到底部」按钮未出现（following 未解除）"
        )
    }

    /// 点击「回到底部」按钮后，按钮必须消失（恢复跟随）。
    func testBackToBottomButtonRestoresFollowing() throws {
        try prepareScrollFixture()

        let backToBottom = element(identifier: "lumi.message.zcode.back-to-bottom")
        XCTAssertTrue(backToBottom.waitForExistence(timeout: 10), "上滚后「回到底部」按钮未出现")

        backToBottom.click()

        // 按钮必须消失（恢复跟随）。
        let disappeared = NSPredicate(format: "exists == false")
        expectation(for: disappeared, evaluatedWith: backToBottom)
        waitForExpectations(timeout: 10)
    }

    /// 用户往**前**滚（回到底部）后，按钮必须消失（恢复跟随）。
    ///
    /// - Important: 这里不追求「一路滚到最底」—— XCUI 的 swipe 在长列表上
    ///   很难精确落到底部，测出来的位置是随机的。
    ///   真正要守住的语义是：**用户主动往前滚时，跟随状态由几何说了算**。
    ///
    ///   因此断言的是「往前滚之后按钮消失」，
    ///   即用户不再停留在脱离跟随的状态。
    func testScrollingForwardRestoresFollowing() throws {
        try prepareScrollFixture()

        let backToBottom = element(identifier: "lumi.message.zcode.back-to-bottom")
        XCTAssertTrue(backToBottom.waitForExistence(timeout: 10), "上滚后「回到底部」按钮未出现")

        // 往前滚：多次滚动，直到按钮消失为止。
        //
        // - Important: 次数要多 —— 长列表有 30 轮，
        //   一次 swipe 只挪几百像素，离底还远得很。
        let list = element(identifier: "lumi.message.zcode.list")
        // 往前滚：多次滚动，直到按钮消失为止。
        //
        // - Important: 次数要多 —— 长列表有 30 轮，
        //   一次 swipe 只挪几百像素，离底还远得很。
        for _ in 0..<12 {
            scrollWheel(at: list, deltaY: 900)
            if !backToBottom.exists { break }
        }

        let disappeared = NSPredicate(format: "exists == false")
        expectation(for: disappeared, evaluatedWith: backToBottom)
        waitForExpectations(timeout: 20)
    }

    // MARK: - Helpers

    /// 准备滚动夹具：切到长列表会话、切到 V4、等遮罩消失、然后上滚离底。
    private func prepareScrollFixture() throws {
        switchConversation(to: MessageListZCodeUITestTitles.scroll)
        switchToVerbosity(.zcode)
        XCTAssertNotNil(measureMaskLifetime(timeout: maskBudget), "首屏遮罩未消失")

        let list = element(identifier: "lumi.message.zcode.list")
        XCTAssertTrue(list.waitForExistence(timeout: 15), "V4 列表容器未出现")

        // 先把 App 激活到前台：CGEvent 派发到 HID tap 时，
        // 只有前台应用才会收到。
        app.activate()
        Thread.sleep(forTimeInterval: 0.5)

        // 多次滚动：单次可能不足以越过 48px 阈值。
        for _ in 0..<3 {
            scrollWheel(at: list, deltaY: -400)
        }
        Thread.sleep(forTimeInterval: 0.5)

        // 诊断：打印 AX 树里的标识符与滚动位置。
        print("🔎 list frame=\(list.frame)")
        let ids = list.descendants(matching: .any)
            .allElementsBoundByIndex
            .filter { !$0.identifier.isEmpty }
            .map { "\($0.identifier)" }
        print("🔎 标识符集合：\(Set(ids).sorted())")
        let back = element(identifier: "lumi.message.zcode.back-to-bottom")
        print("🔎 back-to-bottom exists=\(back.exists)")
        let scrollArea = list.descendants(matching: .any)
            .allElementsBoundByIndex
            .filter { $0.value as? String != nil }
            .prefix(10)
            .map { "\($0.elementType.rawValue):\($0.value ?? "")" }
        print("🔎 value 样本：\(scrollArea)")
    }

    /// 测量遮罩寿命。
    private func measureMaskLifetime(timeout: TimeInterval) -> TimeInterval? {
        let mask = element(identifier: maskIdentifier)
        guard mask.waitForExistence(timeout: 2) else {
            print("📊 [\(name)] mask never appeared → no lifetime to measure")
            return 0
        }

        let start = Date()
        let cleared = !mask.waitForNonExistence(timeout: timeout)
        let elapsed = Date().timeIntervalSince(start)
        print("📊 [\(name)] mask lifetime=\(String(format: "%.3f", elapsed))s "
              + "cleared=\(cleared) budget=\(String(format: "%.1f", timeout))s")
        return cleared ? elapsed : nil
    }

    /// 在会话列表里点击指定标题。
    private func switchConversation(to title: String) {
        let row = conversationRow(title)
        XCTAssertTrue(
            row.waitForExistence(timeout: 15),
            "会话「\(title)」在列表中不可见（列表容器内未找到）"
        )
        row.click()
    }

    /// 定位一条会话行。
    private func conversationRow(_ title: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.listID)
            .descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.itemID)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", title, title))
            .firstMatch
    }

    /// 在指定元素上合成滚轮事件。
    ///
    /// - Important: 必须用 `CGEvent` 合成**滚轮**事件：
    ///   `XCUICoordinate` 没有 `scrollUp` / `scrollDown`，
    ///   而 `XCUIElement.swipeUp()` 走的是拖拽路径，
    ///   产生的 `scrollingDeltaY` 语义与真实滚轮不同，
    ///   测出来的「滚不动」全是伪结论。
    ///
    /// - Parameter deltaY: 正值让**内容向上移动**（视口往下走、看到更晚的内容）；
    ///   负值让内容向下移动（视口往上走、看到更早的内容）。
    ///
    ///   - Important: 方向与直觉相反。AppKit 的 `scrollingDeltaY > 0`
    ///     表示内容向上移动，因此**想离底（往回看）要用正值**。
    private func scrollWheel(at element: XCUIElement, deltaY: Int) {
        let frame = element.frame
        guard frame.width > 0, frame.height > 0 else {
            XCTFail("目标元素没有有效尺寸，无法滚动")
            return
        }

        // - Important: 优先用 XCUI 的 `scrollViews` 元素 + `swipeUp/swipeDown`：
        //   它直接驱动底层的 NSScrollView，滚动一定发生。
        //   合成 `CGEvent` 走 HID tap，在 UI 测试宿主里常常打空
        //   （症状：内容纹丝不动）。
        //
        //   方向映射：XCUI 的 `swipeUp` 是「手指向上划」，内容因此**向下**移动
        //   （`scrollingDeltaY < 0`，视口往上走、看到更早的内容）→ `deltaY > 0`；
        //   `swipeDown` 反之（`scrollingDeltaY > 0`，看到更晚的内容）→ `deltaY < 0`。
        if let scrollView = messageListScrollView() {
            if deltaY > 0 {
                scrollView.swipeUp(velocity: .fast)
            } else {
                scrollView.swipeDown(velocity: .fast)
            }
            Thread.sleep(forTimeInterval: 0.6)
            return
        }

        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("无法合成滚轮事件")
            return
        }
        scrollEvent.location = CGPoint(x: frame.midX, y: frame.midY)
        scrollEvent.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// 找到**消息列表**对应的滚动视图。
    ///
    /// - Important: 不能用 `app.scrollViews.firstMatch`。Lumi 窗口里有多个
    ///   NSScrollView（会话列表、消息列表、输入区…），`firstMatch` 拿到的是
    ///   布局上靠前的那个（**会话列表**，frame 宽 240）。
    ///   可靠判据是**尺寸**：消息列表是窗口里最宽的那块。
    ///   判据与 `LumiMessageListBottomScrollUITests` 一致。
    private func messageListScrollView() -> XCUIElement? {
        let candidates = app.scrollViews.allElementsBoundByIndex
        guard !candidates.isEmpty else { return nil }
        let widest = candidates.max { $0.frame.width < $1.frame.width }
        return widest?.frame.width ?? 0 >= 400 ? widest : candidates.first
    }

    /// 切换回复级别。
    private func switchToVerbosity(_ verbosity: MessageListZCodeUITestVerbosity) {
        let control = app.descendants(matching: .any)
            .matching(identifier: "lumi.settings.response-verbosity")
            .firstMatch
        guard control.exists else {
            print("ℹ️ [\(name)] 未找到回复级别控件，跳过 \(verbosity.rawValue) 切换")
            return
        }
        control.click()
        let option = app.descendants(matching: .any)
            .matching(identifier: "lumi.settings.response-verbosity.\(verbosity.rawValue)")
            .firstMatch
        if option.waitForExistence(timeout: 5) {
            option.click()
        }
    }
}
