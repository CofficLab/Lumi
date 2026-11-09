import XCTest
import AppKit

/// V4（ZCode）消息列表的 UI 测试。
///
/// ## 夹具
///
/// `--lumi-ui-testing-message-list-zcode` 植入 5 个**固定**会话：
/// - `ZCode Visual Target`：常规轮次（用户气泡 + 助手正文 + 轮尾操作栏）；
/// - `ZCode Long User Target`：超长用户输入，触发长文折叠；
/// - `ZCode Tool Target`：两个 Explore/Execute 工具，触发工作历史分组；
/// - `ZCode Scroll Target`：30 轮长列表，用于滚动与 following 语义；
/// - `ZCode Streaming Target`：流式态验收。
///
/// ## 隔离
///
/// 所有用例都带 `--lumi-ui-testing-isolated-storage`，数据根落到临时目录，
/// 不触碰用户真实数据，也不连真实供应商（夹具在缺少
/// `--lumi-ui-testing` 时拒绝启动）。
final class LumiMessageListZCodeUITests: LumiUITestCase {
    /// 遮罩的稳定标识符，与 `MessageLoadingView.identifier` 一致。
    private let maskIdentifier = "lumi.message-list.loading-mask"

    /// 遮罩必须在此时间内消失。
    private let maskBudget: TimeInterval = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
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

    /// 5 个夹具会话都必须出现在会话列表里。
    ///
    /// - Important: 这是「夹具真的被种下去了」的最直接证据。
    ///   夹具没种进去时，后续所有呈现断言都无从谈起。
    func testAllZCodeFixtureConversationsExist() throws {
        for title in MessageListZCodeUITestTitles.all {
            XCTAssertTrue(
                element(containingLabel: title).waitForExistence(timeout: 30),
                "夹具会话「\(title)」未出现在会话列表"
            )
        }
    }

    /// 切到任一夹具会话，首屏遮罩都必须及时消失。
    ///
    /// - Important: V4 的遮罩由 `InitialPositionGate` 的预算兜底唯一决定，
    ///   与 V1–V3 各自独立。V4 通过不能说明 V3 通过，反之亦然。
    func testFirstScreenMaskClearsPromptlyForEveryFixture() throws {
        for title in MessageListZCodeUITestTitles.all {
            switchConversation(to: title)

            let elapsed = measureMaskLifetime(timeout: maskBudget)
            XCTAssertNotNil(
                elapsed,
                "会话「\(title)」的首屏遮罩在 \(Int(maskBudget))s 内未消失"
            )
        }
    }

    /// 切到长列表会话后遮罩同样必须消失。
    ///
    /// 30 轮长列表最容易逼近收敛上限、也最容易把遮罩挂住。
    func testScrollFixtureMaskClearsPromptly() throws {
        switchConversation(to: MessageListZCodeUITestTitles.scroll)

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "长列表会话的首屏遮罩在 \(Int(maskBudget))s 内未消失")
    }

    // MARK: - Helpers

    /// 测量遮罩寿命。
    ///
    /// - Important: 先等遮罩**出现**再等它消失，测的是真实寿命。
    ///   只调 `waitForNonExistence` 会得到假数据：切换动作本身有几十到几百毫秒的
    ///   AX 往返，若遮罩在这段时间内已消失，测出的就是「AX 调用耗时」而非遮罩寿命。
    ///
    /// - Returns: 遮罩寿命；超时未消失返回 nil；未出现返回 0。
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
    ///
    /// - Important: 查询必须限定在**列表容器内**（`listID`）。会话标题在
    ///   消息列表正文里也存在同名前缀，全窗口搜索会命中消息正文而非会话行，
    ///   点击后选中态不变，表现为「切换没生效」，极具误导性。
    private func switchConversation(to title: String) {
        let row = conversationRow(title)
        XCTAssertTrue(
            row.waitForExistence(timeout: 15),
            "会话「\(title)」在列表中不可见（列表容器内未找到）"
        )
        row.click()
    }

    /// 定位一条会话行：限定列表容器 → 按 item 标识筛出所有行 → 按 label 匹配标题。
    private func conversationRow(_ title: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.listID)
            .descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.itemID)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", title, title))
            .firstMatch
    }
}

/// V4 夹具会话标题。
///
/// - Note: 与 `MessageListZCodeUITestingSupport.fixtureTitles` 一一对应。
///   标题是 UI 测试的定位锚点，改动会让既有截图失效。
enum MessageListZCodeUITestTitles {
    static let visual = "ZCode Visual Target"
    static let longUser = "ZCode Long User Target"
    static let tool = "ZCode Tool Target"
    static let scroll = "ZCode Scroll Target"
    static let streaming = "ZCode Streaming Target"

    static let all = [visual, longUser, tool, scroll, streaming]
}
