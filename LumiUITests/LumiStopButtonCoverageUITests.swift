import XCTest

/// 停止按钮在**回合各种状态**下的可用性 UI 测试。
///
/// `LumiSendActionBarUITests` / `LumiSendActionBarRaceUITests` 覆盖的是
/// 「回合正在产出」这一种状态。这份文件补上它们结构上覆盖不到的三类：
///
/// 1. **挂起等待提问**（`ask_user`）：回合没在产出，但也没干完。
/// 2. **挂起等待授权**（高风险工具）：同上，且界面上还留着一张授权卡片。
/// 3. **恢复回合中**：用户回答后回合继续跑，但会话状态快照还没更新。
///
/// 三者的共同症状是同一个：停止按钮要么根本不出现，要么出现了点了没反应。
/// 用户按「停止」却看着 Agent 接着干，是最伤信任的一种故障。
///
/// ## 确定性来源（三层夹具）
///
/// 1. `--lumi-ui-testing`：注册确定性 LLM 供应商。模型名决定桩行为：
///    `ui-test-ask-user-yes-no` 挂起等提问、`ui-test-approval` 挂起等授权、
///    `ui-test-ask-user-yes-no-slow` 的**恢复轮**被拉长成多段慢响应，
///    让「恢复回合中」成为一个可稳定采样的状态。
/// 2. `--lumi-ui-testing-isolated-storage`：数据目录重定向到临时目录，
///    每个用例都从「无历史会话」开始。
/// 3. `LumiUITestCase.typeAndSend` 走**点击发送按钮**而非 `typeKey(.return)`：
///    Return 会被宿主输入法候选栏吞掉。
final class LumiStopButtonCoverageUITests: LumiUITestCase {

    // MARK: - Identifiers

    /// 操作栏与卡片的无障碍标识符。
    ///
    /// 必须按标识符定位：AX label 是本地化文案，随 `-AppleLanguages` 变化。
    private enum Identifiers {
        static let editor = "lumi.conversation-input.editor"
        static let sendButton = "lumi.conversation-input.send"
        static let stopButton = "lumi.conversation-input.stop"
        /// ask_user 问题卡片容器。
        static let askUserCard = "lumi.ask-user.card"
        /// ask_user 选项按钮。
        static func askUserOption(_ index: Int) -> String { "lumi.ask-user.option.\(index)" }
        /// 高风险工具授权卡片容器。
        static let approvalCard = "lumi.tool-approval.card"
    }

    /// 桩供应商产出的稳定文案。
    ///
    /// 与 `PluginLLMProviderUITest.UITestFixtures` 对应；常量定义在 App 进程外，
    /// 故此处以字面量书写，改动桩文案会让本文件断言失败（预期的显式耦合）。
    private enum Stub {
        static let yesNoQuestion = "UI Testing Continue?"
        /// 慢恢复场景的完整收尾正文。
        ///
        /// 桩把它拆成 16 段慢速吐出，因此只有整段跑完才会出现这个完整串。
        static let slowResumeFullResponse = "UI Testing Slow Resumed Turn"
    }

    /// 慢恢复场景的实测回合时长（秒），含余量。
    ///
    /// 桩层约 6.4s（16 段 × 0.4s）；留出余量吸收 App 首帧与渲染开销。
    private let resumedTurnDuration: UInt32 = 12

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 确定性 LLM 供应商 + 隔离存储。
            "--lumi-ui-testing",
            "--lumi-ui-testing-isolated-storage",
        ])
    }

    override func tearDownWithError() throws {
        // 等 App 真正退出，避免「上一个用例还在退出」漂移成「下一个用例偶发失败」。
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// 切到指定桩模型。
    ///
    /// 复刻 `LumiAskUserUITests.selectStubModel`：UI 测试供应商 `isLocal = true`，
    /// 因此位于模型选择器的「本地」页签。
    ///
    /// - Important: 这里的等待时间给得比常规长。弹窗是 SwiftUI 懒加载的，
    ///   机器负载高时首帧可能好几秒才出，5s 的等待会偶发性地把
    ///   「弹窗还没渲染完」误判成「页签不存在」。
    private func selectStubModel(_ model: String) {
        let selectModelButton = app.buttons["Select Model"]
        XCTAssertTrue(
            selectModelButton.waitForExistence(timeout: 30),
            "Action Bar 缺少模型选择按钮"
        )
        selectModelButton.click()

        let popover = element(identifier: "lumi.model-selector.popover")
        XCTAssertTrue(
            popover.waitForExistence(timeout: 20),
            "模型选择弹窗未出现"
        )

        // 点页签可能要重试：弹窗刚出现时分段控件可能还没可交互。
        let localSegment = app.radioButtons["Local"]
        var localSwitched = false
        for _ in 0..<3 where !localSwitched {
            XCTAssertTrue(
                localSegment.waitForExistence(timeout: 15),
                "供应商列表缺少 Local 页签"
            )
            localSegment.click()
            // 页签切换后列表要重新筛选，留稳定期再断言，避免读到切换前的快照。
            sleep(1)
            localSwitched = element(identifier: "lumi.model-selector.provider.ui-test").exists
        }
        XCTAssertTrue(
            localSwitched,
            """
            本地供应商列表缺少 UI Test。实际可见：\
            \(visibleProviderRows())
            """
        )

        let providerRow = element(identifier: "lumi.model-selector.provider.ui-test")
        providerRow.click()

        let modelRow = element(identifier: "lumi.model-selector.model.\(model)")
        XCTAssertTrue(
            modelRow.waitForExistence(timeout: 20),
            "模型列表缺少 \(model)"
        )
        modelRow.click()

        // 选中模型会关闭弹窗；等它消失，避免与后续点击争抢命中测试。
        _ = popover.waitForNonExistence(timeout: 10)
        // 弹窗关闭后输入框需重新拿回焦点，否则紧随其后的点击会落空。
        sleep(1)
    }

    /// 当前可见的供应商行，用于失败时定位是「页签没切过去」还是「供应商没注册」。
    private func visibleProviderRows() -> [String] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "lumi.model-selector.provider."))
            .allElementsBoundByIndex
            .map { "\($0.identifier)=\($0.label)" }
    }

    /// 断言停止按钮可见、发送按钮不可见。
    ///
    /// 「任何时刻只有一个按钮」是 Action Bar 的核心不变量：
    /// 用户永远只需要认识一个按钮。
    private func assertOnlyStopButtonVisible(context: String) {
        XCTAssertTrue(
            element(identifier: Identifiers.stopButton).waitForExistence(timeout: 20),
            "\(context)：没有停止按钮"
        )
        XCTAssertFalse(
            element(identifier: Identifiers.sendButton).exists,
            "\(context)：不应同时渲染发送按钮"
        )
    }

    /// 断言停止按钮消失、发送按钮回来。
    private func assertOnlySendButtonVisible(context: String) {
        XCTAssertTrue(
            element(identifier: Identifiers.sendButton).waitForExistence(timeout: 20),
            "\(context)：发送按钮未恢复"
        )
        XCTAssertFalse(
            element(identifier: Identifiers.stopButton).exists,
            "\(context)：不应残留停止按钮"
        )
    }

    // MARK: - Tests

    /// 回合挂在等用户回答时，停止按钮必须出现且点了真的停得住。
    ///
    /// 旧实现里这一态显示的是**发送**按钮：用户想中止一个正在等自己的回合，
    /// 只能干等或在卡片上回答，输入区给不了任何出口。
    func testStopIsAvailableWhileTurnSuspendedOnAskUser() throws {
        waitForMainWindow()
        selectStubModel("ui-test-ask-user-yes-no")

        let prompt = "UI Testing Stop While Ask User Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Identifiers.editor),
            "未找到聊天输入框（identifier=\(Identifiers.editor)）"
        )

        // 提问卡片出现 = 回合已挂起。
        XCTAssertTrue(
            element(identifier: Identifiers.askUserCard).waitForExistence(timeout: 40),
            """
            ask_user 问题卡片未出现，回合没有进入挂起态，\
            本用例测不到「挂起时能不能停」
            """
        )

        // 关键断言 1：挂起态也显示停止按钮。
        assertOnlyStopButtonVisible(context: "挂起等待提问时")

        element(identifier: Identifiers.stopButton).click()

        // 关键断言 2：停止后回合真的停了——发送按钮回来，提问卡片消失。
        //
        // 卡片消失是「回合已死」的可观测证据：它由挂起点驱动，
        // 挂起点随取消被清除。
        assertOnlySendButtonVisible(context: "停止挂起回合后")
        XCTAssertTrue(
            element(identifier: Identifiers.askUserCard).waitForNonExistence(timeout: 15),
            """
            停止后提问卡片仍留在界面上，\
            它等的是一个已经不存在的回合
            """
        )
    }

    /// 回合挂在等高风险工具授权时，停止按钮必须出现，且授权卡片随之消失。
    ///
    /// 这条比上一条多一层要求：授权卡片是渲染自**已落库的消息**的
    /// （`authorizationState == pendingAuthorization` 且仍在等待用户响应），
    /// 回合取消不会自动改写这些字段。不写回终态的话，卡片会一直留在界面上，
    /// 用户点「允许」只会拿到一个不存在的回合。
    func testStopIsAvailableWhileTurnSuspendedOnToolApproval() throws {
        waitForMainWindow()
        selectStubModel("ui-test-approval")

        let prompt = "UI Testing Stop While Approval Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Identifiers.editor),
            "未找到聊天输入框"
        )

        XCTAssertTrue(
            element(identifier: Identifiers.approvalCard).waitForExistence(timeout: 40),
            """
            授权卡片未出现，回合没有进入挂起态，\
            本用例测不到「等授权时能不能停」
            """
        )

        assertOnlyStopButtonVisible(context: "挂起等待授权时")

        element(identifier: Identifiers.stopButton).click()

        assertOnlySendButtonVisible(context: "停止挂起回合后")
        XCTAssertTrue(
            element(identifier: Identifiers.approvalCard).waitForNonExistence(timeout: 15),
            """
            停止后授权卡片仍留在界面上，\
            它等的是一个已经不存在的回合
            """
        )
    }

    /// 恢复回合的过程中，停止按钮必须仍然有效。
    ///
    /// 用户回答提问后回合继续跑，但会话状态快照还没收到新事件，
    /// 仍停留在 `.suspended`。这一段窗口里旧实现是「停止按钮点了没反应」——
    /// 恢复回合从不在 sender 的任务账本里，旧的守门条件直接把它挡在门外。
    ///
    /// 判据是**慢速收尾正文从未完整出现**：桩把收尾拆成 16 段慢速吐出，
    /// 只有整段跑完才会拼出完整串。
    func testStopStopsResumedTurn() throws {
        waitForMainWindow()
        selectStubModel("ui-test-ask-user-yes-no-slow")

        let prompt = "UI Testing Stop While Resumed Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Identifiers.editor),
            "未找到聊天输入框"
        )
        XCTAssertTrue(
            element(identifier: Identifiers.askUserCard).waitForExistence(timeout: 40),
            "ask_user 问题卡片未出现，回合没有进入挂起态"
        )

        // 回答提问 → 回合恢复，进入慢速收尾。
        let option = element(identifier: Identifiers.askUserOption(1))
        XCTAssertTrue(
            option.waitForExistence(timeout: 10),
            "yes_no 的第二个选项未出现"
        )
        option.click()

        // 恢复窗口里停止按钮必须仍然可见（状态快照还停在 suspended）。
        assertOnlyStopButtonVisible(context: "恢复回合中")

        element(identifier: Identifiers.stopButton).click()

        // 停止后按钮回落。
        assertOnlySendButtonVisible(context: "停止恢复回合后")

        // 关键断言：慢速收尾正文从未完整出现。
        //
        // 回合自然跑完也会让按钮回落，所以只断言按钮是不够的；
        // 必须证明回合是被停掉的，而不是自己跑完的。
        sleep(resumedTurnDuration)
        XCTAssertFalse(
            element(anyLabelOf: [Stub.slowResumeFullResponse]).exists,
            """
            点击停止后仍出现完整收尾回复「\(Stub.slowResumeFullResponse)」，\
            说明恢复回合没有被真正取消，只是按钮形态变了
            """
        )
    }
}
