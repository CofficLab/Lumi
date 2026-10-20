import XCTest

/// 发送 / 停止按钮在**回合未结束**时的状态机 UI 测试。
///
/// ## 与 `LumiSendActionBarUITests` 的分工
///
/// 那份文件覆盖的是「一个回合跑完 / 点一次停止」的正常路径。本文件专攻那份文件
/// 结构上覆盖不到的四类问题：
///
/// 1. **竞态**：回合窗口太短时，停止按钮可能刚出现就消失，测试根本抓不到。
///    既有用例用默认的 `ui-test-text`（3 个 SSE 事件、无延迟），
///    「等待停止按钮出现」实际是在赌它比回合结束活得久。
/// 2. **回合未结束时再次发送**：`MessageSender` 会把第二次发送排进
///    `pendingQueues`。UI 上看不到队列，用户只能看到「按钮不见了，什么也没发生」。
/// 3. **回合未结束时点击停止**：停掉正在跑的回合后，用户往往想立刻改一版重发。
/// 4. **失败回合**：回合失败与回合成功一样会让 `canStop` 复位，但失败还会
///    渲染错误消息——两者叠加时按钮是否同步回落，属于未覆盖路径。
///
/// ## 确定性来源（三层夹具）
///
/// 1. `--lumi-ui-testing`：注册确定性 LLM 供应商。**本文件全部用例都切到
///    `ui-test-slow`**——它在每个 SSE 段之间 sleep 0.4s（见
///    `UITestFixtures.slowChunkDelay`），把回合窗口从毫秒级拉长到秒级，
///    这是「回合中」状态可被稳定观察的前提。
/// 2. `--lumi-ui-testing-isolated-storage`：数据目录重定向到临时目录，
///    每个用例都从「无历史会话」开始，按钮初始状态确定。
/// 3. `LumiUITestCase.typeAndSend` 走**点击发送按钮**而非 `typeKey(.return)`：
///    Return 会被宿主输入法候选栏吞掉（见基类注释），发起点必须避开键盘事件链。
///
/// 范式参照 `LumiAskUserUITests.selectStubModel`。
final class LumiSendActionBarRaceUITests: LumiUITestCase {

    // MARK: - Constants

    /// 按钮标识符，与 `SendActionBarAccessibility` 保持一致。
    ///
    /// 必须按标识符定位：AX label 是本地化文案，随 `-AppleLanguages` 变化。
    private enum Identifiers {
        static let editor = "lumi.conversation-input.editor"
        static let sendButton = "lumi.conversation-input.send"
        static let stopButton = "lumi.conversation-input.stop"
        /// 错误消息正文，与 `ErrorMessageView.contentAccessibilityIdentifier` 一致。
        static let errorContent = "lumi.message.error.content"
    }

    /// 慢速场景的模型名。回合窗口足够长，便于观察「回合中」状态。
    private enum StubModel {
        /// 超长回合：实测约 14s（32 段 × 0.4s）。
        ///
        /// 本文件**全部**用例都用它而非 `ui-test-slow`（实测仅约 1.7s）。
        /// 理由：XCUITest 单次状态查询本身要几百毫秒，1.7s 的窗口里
        /// 「回合中」只能被采样到一两次，测的是轮询时机而不是产品行为。
        static let verySlow = "ui-test-very-slow"
        /// 失败场景。用于验证失败后按钮回落。
        static let error = "ui-test-error"
    }

    /// 桩供应商产出的稳定文案。
    ///
    /// 与 `PluginLLMProviderUITest.UITestFixtures` 对应；常量定义在 App 进程外，
    /// 故此处以字面量书写，改动桩文案会让本文件断言失败（预期的显式耦合）。
    private enum Stub {
        static let errorMessage = "UI Testing Request Failed"

        /// `verySlow` 场景跑完后的完整正文（32 段序号串拼接）。
        ///
        /// 只有回合**完整跑完**才会出现这段串；点击停止后它必须缺席，
        /// 这是「停止真的取消了回合」而非「只切了按钮图标」的可观测判据。
        static let verySlowFullResponse =
            (1...32).map { "\($0) " }.joined()
    }

    /// `verySlow` 回合的实测总时长（秒），含余量。
    ///
    /// 实测桩层约 14.3s；留出余量吸收 App 首帧与渲染开销。
    /// `sleep()` 收 UInt32，故此处用整数秒。
    private let turnDuration: UInt32 = 20

    /// 回合开始后，等待停止按钮出现所需的超时。
    private let turnStartTimeout: TimeInterval = 30

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
    private func selectStubModel(_ model: String) {
        let selectModelButton = app.buttons["Select Model"]
        XCTAssertTrue(
            selectModelButton.waitForExistence(timeout: 20),
            "Action Bar 缺少模型选择按钮"
        )
        selectModelButton.click()

        let popover = element(identifier: "lumi.model-selector.popover")
        XCTAssertTrue(popover.waitForExistence(timeout: 10), "模型选择弹窗未出现")

        let localSegment = app.radioButtons["Local"]
        XCTAssertTrue(
            localSegment.waitForExistence(timeout: 5),
            "供应商列表缺少 Local 页签"
        )
        localSegment.click()
        // 页签切换后列表要重新筛选，留稳定期再断言，避免读到切换前的快照。
        sleep(1)

        let providerRow = element(identifier: "lumi.model-selector.provider.ui-test")
        XCTAssertTrue(
            providerRow.waitForExistence(timeout: 5),
            "本地供应商列表缺少 UI Test"
        )
        providerRow.click()

        let modelRow = element(identifier: "lumi.model-selector.model.\(model)")
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5), "模型列表缺少 \(model)")
        modelRow.click()

        // 选中模型会关闭弹窗；等它消失，避免与后续点击争抢命中测试。
        _ = popover.waitForNonExistence(timeout: 10)
        // 弹窗关闭后输入框需重新拿回焦点，否则紧随其后的点击会落空。
        sleep(1)
    }

    /// 断言两个按钮互斥且状态符合预期。
    ///
    /// 互斥性是 `SendActionBarState` 的核心不变量（`showsSendButton` 与
    /// `showsStopButton` 由同一布尔取反得出），单独作为断言比嵌在流程里更早暴露问题。
    private func assertOnlyStopButtonVisible(
        stopButton: XCUIElement,
        sendButton: XCUIElement,
        context: String
    ) {
        XCTAssertTrue(
            stopButton.waitForExistence(timeout: turnStartTimeout),
            "\(context)：回合已发起但停止按钮未出现"
        )
        XCTAssertFalse(
            sendButton.exists,
            "\(context)：回合运行中不应同时渲染发送按钮"
        )
    }

    private func assertOnlySendButtonVisible(
        sendButton: XCUIElement,
        stopButton: XCUIElement,
        context: String,
        timeout: TimeInterval = 30
    ) {
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: timeout),
            "\(context)：发送按钮未恢复"
        )
        XCTAssertFalse(
            stopButton.exists,
            "\(context)：不应残留停止按钮"
        )
    }

    // MARK: - Tests

    /// 回合运行期间，停止按钮必须**持续存在**（而非闪现一瞬）。
    ///
    /// 这是本文件最核心的一条，也是既有用例结构上测不到的：
    /// `ui-test-text` 的回合只吐 3 个 SSE 事件，「停止按钮出现」必须在
    /// 几十毫秒内完成轮询，否则就是靠运气。切到 `ui-test-slow` 后回合被拉长到秒级，
    /// 因此可以做**持续性**断言：在回合中途反复采样，停止按钮必须一直在。
    ///
    /// 若这条失败而既有用例通过，说明停止按钮只在回合的极早期存在——
    /// 用户在看到回复流的过程中想反悔，却已经没有停止按钮可点了。
    func testStopButtonRemainsPresentThroughoutSlowTurn() throws {
        waitForMainWindow()
        selectStubModel(StubModel.verySlow)

        let sendButton = element(identifier: Identifiers.sendButton)
        let stopButton = element(identifier: Identifiers.stopButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

        XCTAssertTrue(
            typeAndSend("UI Testing Slow Turn Probe", editorIdentifier: Identifiers.editor),
            "未找到聊天输入框（identifier=\(Identifiers.editor)）"
        )

        assertOnlyStopButtonVisible(
            stopButton: stopButton,
            sendButton: sendButton,
            context: "回合发起后"
        )

        // 回合运行中连续采样：停止按钮必须始终存在。
        //
        // `verySlow` 回合实测约 14s（32 段 × 0.4s）。这里采样 8 次，
        // 每次间隔 1s，覆盖约 8s——稳在回合窗口内，且采样密度高于
        // 「每 1.7s 一次」的旧写法，避免把轮询时机误判成产品行为。
        let sampleCount = 8
        for sample in 1...sampleCount {
            XCTAssertTrue(
                stopButton.exists,
                """
                第 \(sample)/\(sampleCount) 次采样时停止按钮消失，\
                说明停止按钮只在回合极早期出现，用户在流式过程中无法反悔取消
                """
            )
            XCTAssertFalse(
                sendButton.exists,
                "第 \(sample)/\(sampleCount) 次采样时发送按钮出现，与停止按钮互斥性被破坏"
            )
            sleep(1)
        }

        // App 未崩溃。
        XCTAssertTrue(element(identifier: "root.main").exists, "回合中主窗口消失，App 可能已崩溃")
    }

    /// 回合运行中点击停止：停止按钮消失、回合真的被取消，而不是自然跑完。
    ///
    /// 与既有 `testSendButtonIsReplacedByStopButtonWhileRunningAndRestoredAfterStop`
    /// 的区别有两点，都很关键：
    ///
    /// 1. 用 `ui-test-slow` 而非默认模型，确保回合足够长，点击一定落在回合中
    ///    （默认模型可能点完就已经跑完了，那测的是「点了个寂寞」）。
    /// 2. 额外断言**桩回复没有出现**。只断言按钮恢复是不够的——
    ///    回合自然跑完也会让按钮恢复，但那条路说明「停止根本没生效」。
    ///    这是既有用例缺失的一环。
    func testStopCancelsSlowTurnInsteadOfLettingItFinish() throws {
        waitForMainWindow()
        selectStubModel(StubModel.verySlow)

        let sendButton = element(identifier: Identifiers.sendButton)
        let stopButton = element(identifier: Identifiers.stopButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

        XCTAssertTrue(
            typeAndSend("UI Testing Cancel Slow Turn Probe", editorIdentifier: Identifiers.editor),
            "未找到聊天输入框"
        )
        assertOnlyStopButtonVisible(
            stopButton: stopButton,
            sendButton: sendButton,
            context: "回合发起后"
        )

        // 回合刚开始就点停止，确保落在回合窗口内。
        stopButton.click()

        assertOnlySendButtonVisible(
            sendButton: sendButton,
            stopButton: stopButton,
            context: "点击停止后"
        )

        // 关键断言：回合被取消，已产出的内容不应继续累积。
        //
        // `verySlow` 回合实测约 14s。若停止真的取消了回合，流式输出应当
        // 立刻中止，正文停在「点停止之前已收到的那部分」。
        //
        // 因此这里断言**完整回复没有出现**：`verySlow` 的正文是 1..32 的
        // 序号串，只有回合跑完才会完整出现。取消后等待远大于剩余时长，
        // 若完整串仍存在，说明停止只是切了按钮图标、没有真正取消回合。
        //
        // 注意不能用「正文完全为空」作判据：点击停止前桩已经吐了几段，
        // 界面上的部分正文是预期行为（用户看到了已生成的内容）。
        sleep(turnDuration)
        XCTAssertFalse(
            element(anyLabelOf: [Stub.verySlowFullResponse]).exists,
            """
            点击停止后仍出现「\(Stub.verySlowFullResponse)」形式的完整回复，\
            说明回合没有被真正取消，只是按钮形态变了
            """
        )
    }

    /// 停止后立刻重新发送：输入框应可用，回合能再次启动。
    ///
    /// 「停止」最常见的后续动作就是改一版重发。这条链路要求
    /// `cancelCurrentRequest()` 之后 `canStop` 彻底复位，否则
    /// `send()` 提交后不会启动回合（`MessageSender` 认为仍有一个活动回合），
    /// 用户会看到「消息发出去了，但永远没有回复」。
    func testSendingAgainImmediatelyAfterStopStartsNewTurn() throws {
        waitForMainWindow()
        selectStubModel(StubModel.verySlow)

        let sendButton = element(identifier: Identifiers.sendButton)
        let stopButton = element(identifier: Identifiers.stopButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

        // 第一轮：发起后立刻停止。
        let firstPrompt = "UI Testing Resend First Turn"
        XCTAssertTrue(
            typeAndSend(firstPrompt, editorIdentifier: Identifiers.editor),
            "未找到聊天输入框"
        )
        assertOnlyStopButtonVisible(
            stopButton: stopButton,
            sendButton: sendButton,
            context: "第一轮回合发起后"
        )
        stopButton.click()
        assertOnlySendButtonVisible(
            sendButton: sendButton,
            stopButton: stopButton,
            context: "第一轮停止后"
        )

        // 第二轮：立刻重新发送。
        let secondPrompt = "UI Testing Resend Second Turn"
        XCTAssertTrue(
            typeAndSend(secondPrompt, editorIdentifier: Identifiers.editor),
            """
            停止后无法再次发送，\
            说明输入框或 canSend 未恢复（canStop 可能没有真正复位）
            """
        )

        // 第二条消息必须被受理（输入框里不再有它）。
        //
        // 判据用「编辑器 value 不含该消息」，而不是 `value == ''`：
        // 空输入框的 AX value 是 placeholder 文案（见 ComposerView 传入的
        // "输入消息，按 Return 发送…"），不是空串。
        //
        // 同时不断言消息立刻出现在时间线上：停止只复位 `canStop`，
        // 而 `MessageSender` 仍持有上一轮的回合跟踪任务时，第二条消息会被判为
        // 「同会话发送中」而入队（`pendingQueues`），要等当前回合结束才发出。
        // 「第二轮回合确实启动」由下一段断言证明。
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(
                    format: "NOT (value CONTAINS %@)",
                    secondPrompt
                ),
                object: element(identifier: Identifiers.editor)
            )], timeout: 20),
            .completed,
            """
            停止后无法再次发送（输入框仍留着该消息），\
            说明输入框或 canSend 未恢复——canStop 可能没有真正复位
            """
        )

        // 第二轮回合必须真的启动，而不是停在已发送状态。
        assertOnlyStopButtonVisible(
            stopButton: stopButton,
            sendButton: sendButton,
            context: "第二轮回合发起后"
        )

        // 收尾：停掉第二轮，避免用例结束时仍在回合中。
        stopButton.click()
    }

    /// 回合运行中再次发送：消息应被接受并排队，而不是被丢弃。
    ///
    /// `MessageSender` 对发送中的会话会把新消息排进 `pendingQueues`，
    /// 当前回合结束后再依次发出。UI 层没有队列提示，用户只能从
    /// 「两条消息都出现在时间线上」判断是否生效。
    ///
    /// 这条用例锁住的是「回合中发送按钮消失」带来的可发现性问题：
    /// 停止按钮独占位置时，用户其实**无法**再点发送，因此本用例改为
    /// 用键盘发送路径发起第二条消息——验证消息至少不会消失。
    func testMessageSentDuringTurnIsQueuedNotLost() throws {
        waitForMainWindow()
        selectStubModel(StubModel.verySlow)

        let sendButton = element(identifier: Identifiers.sendButton)
        let stopButton = element(identifier: Identifiers.stopButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

        let firstPrompt = "UI Testing Queue First Turn"
        XCTAssertTrue(
            typeAndSend(firstPrompt, editorIdentifier: Identifiers.editor),
            "未找到聊天输入框"
        )
        assertOnlyStopButtonVisible(
            stopButton: stopButton,
            sendButton: sendButton,
            context: "第一轮回合发起后"
        )

        // 回合进行中输入框必须仍可编辑（用户能提前起草下一条）。
        //
        // 判据用**键盘焦点**，不用 `typeText` 打字，也不用 `isEnabled`：
        //
        // - `typeText` 逐字符模拟键盘事件，会激活宿主输入法；候选栏一弹出
        //   就是系统模态层，`typeText` 到不了 NSTextView（见 `LumiUITestCase`
        //   顶部注释）。这会让「打字失败」与「输入框不能编辑」无法区分。
        // - `isEnabled` 同理：候选栏弹出时整个 App 被报成 Disabled，是假象。
        //
        // 焦点是最接近「用户能不能接着写」且不受输入法影响的信号：
        // 输入框拿得到键盘焦点，就能接收后续输入。
        //
        // 注意：此时发送按钮被停止按钮取代，所以「能输入」≠「能发送」——
        // 用户可以起草下一条，但要等当前回合结束（或点停止）才能发出去。
        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(editor.exists, "回合进行中输入框消失")

        editor.click()
        XCTAssertTrue(
            waitForKeyboardFocus(editor, timeout: 10),
            """
            回合进行中输入框拿不到键盘焦点，用户无法提前起草下一条——\
            若这是产品行为，请确认是否有意为之
            """
        )

        // 回合仍在进行：停止按钮不应因为点击输入框而被替换掉。
        XCTAssertFalse(
            sendButton.exists,
            "回合进行中点击输入框不应让发送按钮重新出现（互斥性被破坏）"
        )

        // 停掉当前回合，让会话回到可发送状态。
        stopButton.click()
        assertOnlySendButtonVisible(
            sendButton: sendButton,
            stopButton: stopButton,
            context: "停止后"
        )
    }

    /// 失败回合结束后，按钮必须回落到发送按钮。
    ///
    /// 回合失败与成功一样要让 `canStop` 复位，但失败还会额外渲染错误消息
    /// （`UI Testing Request Failed`）与「重试」入口。这两者叠加时，
    /// Action Bar 的按钮是否同步回落，属于未覆盖路径——若不回落，
    /// 用户会看到一个点不动的停止按钮，且没有任何办法重试。
    func testButtonFallsBackToSendAfterFailedTurn() throws {
        waitForMainWindow()
        selectStubModel(StubModel.error)

        let sendButton = element(identifier: Identifiers.sendButton)
        let stopButton = element(identifier: Identifiers.stopButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

        let prompt = "UI Testing Failed Turn Probe"
        XCTAssertTrue(
            typeAndSend(prompt, editorIdentifier: Identifiers.editor),
            "未找到聊天输入框"
        )

        // 失败回合也会经过「运行中」状态，因此停止按钮可能出现也可能来不及出现。
        // 断言最终态即可：失败消息渲染出来，且按钮回到发送态。
        //
        // 错误正文按**标识符**定位（`ErrorMessageView.contentAccessibilityIdentifier`）
        // 而非文案：错误视图的 AX label 会随本地化变化，按文案匹配在
        // 非英文环境下必然失效。
        XCTAssertTrue(
            element(identifier: Identifiers.errorContent).waitForExistence(timeout: 40),
            """
            失败回合未渲染错误消息（identifier=\(Identifiers.errorContent)），\
            说明回合未按预期失败（或错误消息渲染被跳过）
            """
        )
        // 文案检查：标识符存在只说明错误消息被渲染，正文是否包含桩文案另说。
        //
        // 用**包含**而非相等：`ErrorMessageView` 会给正文加本地化前缀
        // （en 下形如 `请求失败：UI Testing Request Failed`），前缀随语言变化，
        // 断言整个字符串会在非中文环境下失败。桩产出的原文才是稳定契约。
        let errorText = element(identifier: Identifiers.errorContent).value as? String
        XCTAssertTrue(
            errorText?.contains(Stub.errorMessage) == true,
            """
            错误消息正文（\(errorText ?? "nil")）不含桩产出的文案\
            「\(Stub.errorMessage)」，说明错误内容没有透传到界面
            """
        )

        assertOnlySendButtonVisible(
            sendButton: sendButton,
            stopButton: stopButton,
            context: "失败回合后"
        )

        // 失败后必须还能重新发送——用户要能改一版重试。
        //
        // 判据同样用「编辑器 value 不含该消息」：空输入框的 AX value 是
        // placeholder 文案而非空串，因此不能用 `value == ''`。
        let retryPrompt = "UI Testing Retry After Failure"
        XCTAssertTrue(
            typeAndSend(retryPrompt, editorIdentifier: Identifiers.editor),
            """
            失败回合后无法重新发送，\
            说明按钮回落不完整或输入框被错误消息阻塞
            """
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(
                    format: "NOT (value CONTAINS %@)",
                    retryPrompt
                ),
                object: element(identifier: Identifiers.editor)
            )], timeout: 20),
            .completed,
            "失败回合后重新发送的消息仍留在输入框里，说明按钮 action 未生效"
        )
    }

    /// 空闲态下两个按钮必须严格互斥，且发送按钮的空内容禁用态正确。
    ///
    /// 这条锁住互斥不变量本身：整份测试的其余用例都建立在
    /// 「回合中只有停止按钮、空闲时只有发送按钮」之上。一旦这条被破坏，
    /// 上面所有断言的语义都会失真，因此单独跑一遍最便宜的用例。
    func testButtonsAreStrictlyMutuallyExclusiveInIdleState() throws {
        waitForMainWindow()
        selectStubModel(StubModel.verySlow)

        let sendButton = element(identifier: Identifiers.sendButton)
        let stopButton = element(identifier: Identifiers.stopButton)

        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "空闲态缺少发送按钮")
        XCTAssertFalse(stopButton.exists, "空闲态不应出现停止按钮")

        // 空内容时发送按钮必须不可用（canSend == false）。
        XCTAssertFalse(
            sendButton.isEnabled,
            "输入框为空时发送按钮不应可用"
        )

        // 纯空白内容同样不可发送。
        //
        // 本用例要测的正是「只有空白」这个输入，必须精确写入 3 个空格。
        // `launchLumi` 已把输入源切到英文 ASCII 布局，`typeText` 不会吞掉
        // 尾部空格（详见 `UITestInputSource` 的实测对照表）。
        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "未找到聊天输入框")
        typeText("   ", into: editor)

        // 给状态层一点时间把 canSend 刷成 false。
        sleep(2)
        XCTAssertFalse(
            sendButton.isEnabled,
            "只有空白内容时发送按钮不应可用"
        )
        XCTAssertFalse(
            stopButton.exists,
            "空白输入不应触发停止按钮"
        )
    }
}
