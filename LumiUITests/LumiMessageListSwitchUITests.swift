import XCTest
import AppKit

/// PluginMessageListStandard（V2 / 标准模式）**会话切换**的 UI 测试。
///
/// ## 要解决的问题
///
/// 用户报告：切换对话时「正在加载消息…」遮罩停留很久，消息列表出现非常慢。
///
/// 遮罩显示条件是 `viewModel.isLoading || !initialPositionGate.isReady`：
/// - `isLoading` 只等消息落库（实测毫秒级）；
/// - `isReady` 等首屏**定位收敛**（`settleBottom` 逐帧钉底，等待
///   `documentHeight` 连续 3 帧稳定）。
///
/// `InitialPositionGate` 的预算（3s）只应在收敛**真的挂死**时兜底；收敛成功
/// 必须立即放行。这些用例验证的正是「收敛成功时遮罩不被预算拖住」。
///
/// ## 夹具
///
/// `--lumi-ui-testing-message-list-standard` 植入两个会话：
/// - `Switch Target Small`：3 轮，几何很快稳定；
/// - `Switch Target Large`：40 轮 + Markdown/代码块，几何持续增长，
///   最容易逼近收敛上限。
///
/// ## 测量方式（重要）
///
/// `measureMaskLifetime` 先等遮罩**出现**再等它消失，测的是真实寿命。
/// 只调 `waitForNonExistence` 会得到假数据：切换动作本身有几十到几百毫秒的
/// AX 往返，若遮罩在这段时间内已消失，测出的就是「AX 调用耗时」而非遮罩寿命
/// ——数字好看，但与用户体验完全无关。这条细节曾让「遮罩在 Ns 内消失」这条断言
/// 在根因存在时也可能通过。
///
/// ## 不覆盖
///
/// - 滚动位置精度（依赖真实 NSScrollView，单元层已覆盖几何与迟滞判据）。
/// - 具体加载耗时阈值以外的视觉回归（由人工验收）。
final class LumiMessageListSwitchUITests: LumiUITestCase {
    /// 遮罩的稳定标识符，与 `MessageLoadingView.identifier` 一致。
    private let maskIdentifier = "lumi.message-list.loading-mask"

    /// 遮罩必须在此时间内消失。
    ///
    /// `InitialPositionGate.budgetNanoseconds` 为 3s —— 那只是收敛**挂死**时的
    /// 兜底，正常收敛应当在几百毫秒内完成。这里留 6s 余量以容忍 CI 负载波动，
    /// 同时仍能捕获「遮罩永久不消失」这一回归。
    private let maskBudget: TimeInterval = 6

    /// 正常收敛的耗时上限（见 `testSwitchDoesNotWaitFullBudgetOnEverySwitch`）。
    ///
    /// 3s 兜底预算的一半：既能捕获「退化成每次都等满预算」（≈3s），
    /// 又远高于首屏 + 富文本预热的正常耗时，两侧都有充足余量。
    private let expectedMaskUpperBound: TimeInterval = 1.5

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

    // MARK: - Cases

    /// 大会话（40 轮富文本）首屏遮罩必须及时消失。
    func testLargeConversationFirstScreenMaskClearsPromptly() throws {
        XCTAssertTrue(
            element(containingLabel: MessageListStandardUITestTitles.large)
                .waitForExistence(timeout: 30),
            "大会话未出现在会话列表"
        )

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "首屏遮罩在 \(Int(maskBudget))s 内未消失（首屏定位未收敛且无兜底）")
    }

    /// 从大会话切到小会话，遮罩必须及时消失。
    func testSwitchFromLargeToSmallClearsMaskPromptly() throws {
        switchConversation(to: MessageListStandardUITestTitles.large)
        _ = measureMaskLifetime(timeout: maskBudget)

        switchConversation(to: MessageListStandardUITestTitles.small)

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "切换到小会话后遮罩在 \(Int(maskBudget))s 内未消失")
    }

    /// 从小会话切回大会话（更难收敛的一侧），遮罩必须及时消失。
    func testSwitchFromSmallToLargeClearsMaskPromptly() throws {
        switchConversation(to: MessageListStandardUITestTitles.small)
        _ = measureMaskLifetime(timeout: maskBudget)

        switchConversation(to: MessageListStandardUITestTitles.large)

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "切换到大会话后遮罩在 \(Int(maskBudget))s 内未消失")
    }

    /// 遮罩**不该**每次切换都等满预算（≈3s）。
    ///
    /// 这是「切换对话时列表出现很慢」最直接的量化回归判据：即使遮罩最终
    /// 在 6s 内消失，若耗时稳定贴近 3s，说明 `InitialPositionGate` 又退化成
    /// 「无条件等满预算再放行」，用户依旧要等约 3 秒才能看到列表。
    func testSwitchDoesNotWaitFullBudgetOnEverySwitch() throws {
        switchConversation(to: MessageListStandardUITestTitles.small)
        _ = measureMaskLifetime(timeout: maskBudget)

        var durations: [TimeInterval] = []
        // 采样 3 次，降低单次抖动影响。
        for index in 0..<3 {
            let target = index.isMultiple(of: 2)
                ? MessageListStandardUITestTitles.large
                : MessageListStandardUITestTitles.small
            switchConversation(to: target)
            if let elapsed = measureMaskLifetime(timeout: maskBudget) {
                durations.append(elapsed)
            }
        }

        guard !durations.isEmpty else {
            return XCTFail("采样期间遮罩从未消失，无法评估耗时")
        }
        let worst = durations.max() ?? 0
        let average = durations.reduce(0, +) / Double(durations.count)
        print("📊 [mask budget regression] samples=\(durations.count) "
              + "average=\(String(format: "%.3f", average))s "
              + "worst=\(String(format: "%.3f", worst))s")

        XCTAssertLessThan(
            worst,
            expectedMaskUpperBound,
            "最慢一次遮罩 \(String(format: "%.2f", worst))s 已贴近 3s 兜底预算，说明收敛成功后仍在等满预算"
        )
    }

    /// 连续快速切换多次，遮罩不得卡死。
    ///
    /// 这条针对「旧会话遗留的滚动任务未失效」这类竞态：快速切换时
    /// 上一轮的等待可能与新一轮重叠，若无代次校验就会互相取消或
    /// 让旧结果覆盖新状态。
    func testRapidSwitchingDoesNotStuckMask() throws {
        let sequence = [
            MessageListStandardUITestTitles.small,
            MessageListStandardUITestTitles.large,
            MessageListStandardUITestTitles.small,
            MessageListStandardUITestTitles.large,
        ]
        for title in sequence {
            switchConversation(to: title)
        }

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "快速连续切换 \(sequence.count) 次后遮罩仍未消失")
    }

    /// 切换后消息内容确实渲染出来了（遮罩消失 ≠ 有内容）。
    func testSwitchedConversationRendersItsOwnMessages() throws {
        switchConversation(to: MessageListStandardUITestTitles.small)
        _ = measureMaskLifetime(timeout: maskBudget)

        XCTAssertTrue(
            element(containingLabel: "小会话回答").firstMatch.waitForExistence(timeout: 20),
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
    ///   消息列表正文里也存在同名前缀（夹具的「大会话问题 N」就渲染在消息区），
    ///   全窗口搜索会命中消息正文而非会话行，点击后选中态不变，
    ///   表现为「切换没生效」，极具误导性。
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

/// 会话列表的可访问性标识符（复述 `ConversationListAccessibility`）。
///
/// UI 测试独立 target，不能 import 插件模块，因此在此复述常量。
/// 改动必须与 `ConversationListAccessibility` 同步。
enum LumiConversationListIDs {
    static let itemID = "lumi.conversation-list.item"
    static let listID = "lumi.conversation-list"
}

/// 夹具会话标题。UI 测试独立于插件模块，故在此复述。
enum MessageListStandardUITestTitles {
    static let small = "Switch Target Small"
    static let large = "Switch Target Large"
}
