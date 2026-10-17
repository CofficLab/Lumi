import XCTest
import AppKit

/// PluginMessageListStandard（V2 / 标准模式）**会话切换**的 UI 测试。
///
/// ## 要解决的问题
///
/// 用户报告：切换对话时「正在加载消息…」遮罩会停留约 10 秒。
///
/// 遮罩显示条件是 `viewModel.isLoading || !initialPositionGate.isReady`：
/// - `isLoading` 只等消息落库（实测毫秒级）；
/// - `isReady` 等首屏**定位收敛**（`settleBottom` 逐帧钉底，等待
///   `documentHeight` 连续 3 帧稳定）。
///
/// 当收敛无法收敛时，该状态曾可永久保持 —— 没有任何重试或超时兜底。
/// `InitialPositionGate` 为首屏定位加了预算上限；这些用例就是验证该预算
/// 真的生效：**遮罩必须在有限时间内消失**。
///
/// ## 夹具
///
/// `--lumi-ui-testing-message-list-standard` 植入两个会话：
/// - `Switch Target Small`：3 轮，几何很快稳定；
/// - `Switch Target Large`：40 轮 + Markdown/代码块，几何持续增长，
///   最容易逼近收敛上限。
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
    /// 预算默认为 3s（见 `InitialPositionGate.budgetNanoseconds`），
    /// 这里留出余量到 8s：既能容忍 CI 机器负载波动，又足以捕获
    /// 「永不消失」这一回归（用户观察到的是 10s 量级）。
    private let maskBudget: TimeInterval = 8

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
        let mask = element(identifier: maskIdentifier)

        // 夹具默认选中大会话，等它出现并消失
        XCTAssertTrue(
            element(containingLabel: "Switch Target Large").waitForExistence(timeout: 30),
            "大会话未出现在会话列表"
        )

        let elapsed = measureMaskLifetime(mask, timeout: maskBudget)
        XCTAssertNotNil(elapsed, "首屏遮罩在 \(Int(maskBudget))s 内未消失（首屏定位未收敛且无兜底）")
    }

    /// 从大会话切到小会话，遮罩必须及时消失。
    func testSwitchFromLargeToSmallClearsMaskPromptly() throws {
        XCTAssertTrue(
            element(containingLabel: "Switch Target Large").waitForExistence(timeout: 30),
            "大会话未出现在会话列表"
        )
        _ = measureMaskLifetime(element(identifier: maskIdentifier), timeout: maskBudget)

        selectConversation(named: MessageListStandardUITestTitles.small)
        switchConversation(to: MessageListStandardUITestTitles.small)

        let elapsed = measureMaskLifetime(element(identifier: maskIdentifier), timeout: maskBudget)
        XCTAssertNotNil(elapsed, "切换到小会话后遮罩在 \(Int(maskBudget))s 内未消失")
    }

    /// 从小会话切回大会话（更难收敛的一侧），遮罩必须及时消失。
    func testSwitchFromSmallToLargeClearsMaskPromptly() throws {
        selectConversation(named: MessageListStandardUITestTitles.small)
        switchConversation(to: MessageListStandardUITestTitles.small)
        _ = measureMaskLifetime(element(identifier: maskIdentifier), timeout: maskBudget)

        switchConversation(to: MessageListStandardUITestTitles.large)

        let elapsed = measureMaskLifetime(element(identifier: maskIdentifier), timeout: maskBudget)
        XCTAssertNotNil(elapsed, "切换到大会话后遮罩在 \(Int(maskBudget))s 内消失失败")
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

        let elapsed = measureMaskLifetime(element(identifier: maskIdentifier), timeout: maskBudget)
        XCTAssertNotNil(elapsed, "快速连续切换 \(sequence.count) 次后遮罩仍未消失")
    }

    /// 切换后消息内容确实渲染出来了（遮罩消失 ≠ 有内容）。
    func testSwitchedConversationRendersItsOwnMessages() throws {
        switchConversation(to: MessageListStandardUITestTitles.small)
        _ = measureMaskLifetime(element(identifier: maskIdentifier), timeout: maskBudget)

        XCTAssertTrue(
            element(containingLabel: "小会话回答").firstMatch.waitForExistence(timeout: 20),
            "切换到小会话后未渲染其消息内容"
        )
    }

    // MARK: - Helpers

    /// 测量遮罩从出现到消失的时长。
    ///
    /// - Returns: 消失耗时；超时未消失返回 nil。
    private func measureMaskLifetime(_ mask: XCUIElement, timeout: TimeInterval) -> TimeInterval? {
        let start = Date()
        // 等遮罩消失（首帧可能已消失，故先给一点出现窗口）
        _ = mask.waitForNonExistence(timeout: timeout)
        let elapsed = Date().timeIntervalSince(start)
        // 遮罩已不存在 = 消失成功；存在则说明超时。
        return mask.exists ? nil : elapsed
    }

    /// 在会话列表里点击指定标题。
    ///
    /// 会话标题可能不在可视区内（Large 排在前面），因此先滚动搜索。
    private func switchConversation(to title: String) {
        let row = element(containingLabel: title)
        if !row.exists {
            // 尝试在会话列表内滚动查找
            let list = app.scrollViews.firstMatch
            for _ in 0..<6 {
                list.swipeUp()
                if element(containingLabel: title).exists { break }
            }
        }
        let target = element(containingLabel: title)
        XCTAssertTrue(
            target.waitForExistence(timeout: 15),
            "会话「\(title)」在列表中不可见"
        )
        target.click()
    }

    /// 让会话标题进入当前作用域（兼容不同列表布局）。
    private func selectConversation(named title: String) {
        switchConversation(to: title)
    }
}

/// 夹具会话标题。UI 测试独立于插件模块，故在此复述。
enum MessageListStandardUITestTitles {
    static let small = "Switch Target Small"
    static let large = "Switch Target Large"
}
