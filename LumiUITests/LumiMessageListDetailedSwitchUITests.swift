import XCTest
import AppKit

/// PluginMessageListDetailed（V3 / 详细模式）**会话切换**的 UI 测试。
///
/// ## 要解决的问题
///
/// 用户报告：切到某个会话后，消息区一直盖着「正在加载消息…」遮罩，
/// 等几十分钟不消失，换到别的会话也还是在加载。
///
/// 遮罩的显示条件原先是 `viewModel.isLoading || !initialPositionGate.isReady`：
/// - `isLoading` 是一个可能停在 true 不再回落的布尔；
/// - `isReady` 的兜底计时器原先挂在「收敛轮次」上 —— 收敛没被启动时，
///   遮罩就永远落不下来；失效的一轮还会把同会话的门禁焊死。
///
/// 现在遮罩的寿命由 gate 的**预算兜底**唯一决定：挂起后最多一个预算，
/// 无论收敛有没有被启动、有没有成功。本组用例守住这条上限。
///
/// ## 夹具
///
/// `--lumi-ui-testing-message-list-detailed` 植入两个会话（详细程度 = detailed，
/// 因此激活的是 **V3** 列表槽位）：
/// - `Detailed Target Small`：3 轮，几何很快稳定；
/// - `Detailed Target Large`：40 轮 + Markdown/代码块，几何持续增长，
///   最容易逼近收敛上限。
///
/// ## 测量方式（重要）
///
/// `measureMaskLifetime` 先等遮罩**出现**再等它消失，测的是真实寿命。
/// 只调 `waitForNonExistence` 会得到假数据：切换动作本身有几十到几百毫秒的
/// AX 往返，若遮罩在这段时间内已消失，测出的就是「AX 调用耗时」而非遮罩寿命。
final class LumiMessageListDetailedSwitchUITests: LumiUITestCase {
    /// 遮罩的稳定标识符，与 `MessageLoadingView.identifier` 一致。
    private let maskIdentifier = "lumi.message-list.loading-mask"

    /// 遮罩必须在此时间内消失。
    ///
    /// `InitialPositionGate.budgetNanoseconds` 为 3s —— 那只是收敛**挂死**时的
    /// 兜底，正常收敛应当在几百毫秒内完成。这里留 6s 余量以容忍 CI 负载波动，
    /// 同时仍能捕获「遮罩永久不消失」这一回归。
    private let maskBudget: TimeInterval = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            "--lumi-ui-testing-message-list-detailed",
            "--lumi-ui-testing-isolated-storage",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Cases

    /// 大会话（40 轮富文本）首屏遮罩必须及时消失。
    func testLargeConversationFirstScreenMaskClearsPromptly() throws {
        XCTAssertTrue(
            element(containingLabel: MessageListDetailedUITestTitles.large)
                .waitForExistence(timeout: 30),
            "大会话未出现在会话列表"
        )

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "首屏遮罩在 \(Int(maskBudget))s 内未消失（首屏定位未收敛且无兜底）")
    }

    /// 从大会话切到小会话，遮罩必须及时消失。
    func testSwitchFromLargeToSmallClearsMaskPromptly() throws {
        switchConversation(to: MessageListDetailedUITestTitles.large)
        _ = measureMaskLifetime(timeout: maskBudget)

        switchConversation(to: MessageListDetailedUITestTitles.small)

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "切换到小会话后遮罩在 \(Int(maskBudget))s 内未消失")
    }

    /// 从小会话切回大会话（更难收敛的一侧），遮罩必须及时消失。
    func testSwitchFromSmallToLargeClearsMaskPromptly() throws {
        switchConversation(to: MessageListDetailedUITestTitles.small)
        _ = measureMaskLifetime(timeout: maskBudget)

        switchConversation(to: MessageListDetailedUITestTitles.large)

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "切换到大会话后遮罩在 \(Int(maskBudget))s 内未消失")
    }

    /// 连续快速切换多次，遮罩不得卡死。
    ///
    /// 这条针对「旧会话遗留的滚动任务未失效」这类竞态：快速切换时
    /// 上一轮的等待可能与新一轮重叠，若无代次校验就会互相取消或
    /// 让旧结果覆盖新状态。
    func testRapidSwitchingDoesNotStuckMask() throws {
        let sequence = [
            MessageListDetailedUITestTitles.small,
            MessageListDetailedUITestTitles.large,
            MessageListDetailedUITestTitles.small,
            MessageListDetailedUITestTitles.large,
        ]
        for title in sequence {
            switchConversation(to: title)
        }

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "快速连续切换 \(sequence.count) 次后遮罩仍未消失")
    }

    /// 切换后消息内容确实渲染出来了（遮罩消失 ≠ 有内容）。
    func testSwitchedConversationRendersItsOwnMessages() throws {
        switchConversation(to: MessageListDetailedUITestTitles.small)
        _ = measureMaskLifetime(timeout: maskBudget)

        XCTAssertTrue(
            element(containingLabel: "详细小会话回答").firstMatch.waitForExistence(timeout: 20),
            "切换到小会话后未渲染其消息内容"
        )
    }

    // MARK: - Helpers

    /// 测量**一次切换**后遮罩的寿命。
    ///
    /// 分两步：先等遮罩出现（证明这次切换确实触发了遮罩），再等它消失。
    /// 起点取「遮罩出现」，终点取「遮罩消失」，中间不含 AX 点击往返，
    /// 因此测到的是用户真正经历的那段遮挡。
    ///
    /// - Note: 若遮罩在观察窗口内从未出现（切换太快、或本就在就绪态），
    ///   返回 `0` —— 此时没有「遮罩消失」这回事可测，把它记成耗时会凭空
    ///   造出一个 0s 的漂亮数字。
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

/// 夹具会话标题。UI 测试独立于插件模块，故在此复述。
enum MessageListDetailedUITestTitles {
    static let small = "Detailed Target Small"
    static let large = "Detailed Target Large"
}
