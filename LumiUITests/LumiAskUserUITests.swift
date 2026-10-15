import XCTest

/// `ask_user` 交互的端到端 UI 测试。
///
/// 单元测试（`AskUserLifecycleTests`）能锁住「挂起点能被解析」「答案会回传给 LLM」，
/// 但它跑在 Provider 层，回答不了用户真正遇到的两个问题：
/// 1. 提问卡片**是否真的渲染在聊天区**、选项能否点击；
/// 2. 点击后回合是否真的恢复、并把答案交给模型继续。
///
/// 两者都必须驱动真实 App 才能验证——SwiftUI 的 `Button` 在 macOS 上不桥接成
/// `NSButton` 子视图，单元测试无法渲染并点击它。
///
/// ## 确定性来源（两层夹具）
///
/// 1. `--lumi-ui-testing`：注册确定性 LLM 供应商并强制选中（见 `PluginUITestProvider`）。
///    本文件通过模型选择器切到 `ui-test-ask-user-*` 系列模型，让桩按**两段式**
///    响应：首轮返回 `ask_user` 工具调用（回合挂起、界面弹出问题卡片），
///    用户回答后第二轮返回固定收尾正文 `UI Testing Ask User Answered`。
///    缺少它，回合会走真实 LLM，界面终态不可预期。
/// 2. `--lumi-ui-testing-isolated-storage`：数据根目录重定向到临时目录，
///    避免测试会话污染用户真实数据库。
///
/// 范式参照 `LumiSendActionBarUITests` 与 `LumiErrorRetryTurnUITests`。
final class LumiAskUserUITests: XCTestCase {
    private var app: XCUIApplication!

    /// 与 `AskUserAccessibility` 保持一致。
    ///
    /// 必须按标识符定位：问题文案与「已回答」提示都是随 `-AppleLanguages` 变化的
    /// 文案，按文案定位在非英文环境下必然失效。
    private enum Identifiers {
        /// 问题卡片容器。
        static let card = "lumi.ask-user.card"
        /// 问题正文。
        static let question = "lumi.ask-user.question"
        /// 选项按钮。
        static func option(_ index: Int) -> String { "lumi.ask-user.option.\(index)" }
        /// free_text 输入框。
        static let freeTextField = "lumi.ask-user.free-text"
        /// free_text 提交按钮。
        static let submitButton = "lumi.ask-user.submit"
        /// 已回答回显。
        static let answered = "lumi.ask-user.answered"
    }

    /// 模型选择器与聊天输入框的标识符。
    private enum Shell {
        static let modelPopover = "lumi.model-selector.popover"
        static let editor = "lumi.conversation-input.editor"
    }

    /// 桩供应商产出的稳定文案。
    ///
    /// 与 `PluginLLMProviderUITest.UITestFixtures` 对应。这些常量定义在 App 进程外，
    /// 故此处以字面量书写；改动桩文案会让本文件断言失败，属于预期的显式耦合。
    private enum Stub {
        static let yesNoQuestion = "UI Testing Continue?"
        static let choiceQuestion = "UI Testing Pick One"
        static let freeTextQuestion = "UI Testing Describe Next Step"
        static let choiceAcceptedOption = "UI Testing Accept"
        static let choiceAcceptedDescription = "Accept and continue"
        static let followUpResponse = "UI Testing Ask User Answered"
        /// 回答 free_text 问题时输入的内容。
        static let freeTextAnswer = "UI Testing Free Text Answer"
    }

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 先终止残留实例（与 LumiSendActionBarUITests 一致），避免复用 Background
        // 旧进程：旧进程里保存着上一次的选中模型与对话，会让回合时机不可预测。
        app.terminate()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // 确定性 LLM 供应商 + 隔离存储。
            "--lumi-ui-testing",
            "--lumi-ui-testing-isolated-storage",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func element(anyLabelOf labels: [String]) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@ OR value IN %@", labels, labels))
            .firstMatch
    }

    /// 隔离数据根目录会让新手引导重新出现（完成标记存在插件数据目录里），
    /// 它覆盖在聊天区之上，不关掉就点不到输入框。
    private func dismissOnboardingIfPresent() {
        for _ in 0..<8 {
            let finish = app.buttons["Finish"]
            let continueButton = app.buttons["Continue"]
            let skip = app.buttons["Skip"]
            if finish.exists, finish.isHittable {
                finish.click()
            } else if continueButton.exists, continueButton.isHittable {
                continueButton.click()
            } else if skip.exists, skip.isHittable {
                skip.click()
            } else {
                return
            }
            sleep(1)
        }
    }

    private func waitForMainWindow() {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30),
            "主窗口未就绪"
        )
        dismissOnboardingIfPresent()
    }

    /// 切换到指定的 UI 测试模型。
    ///
    /// 与「每个场景注册一个供应商」不同，桩让**模型名承载行为**，因此这里走真实
    /// 的模型选择器路径——顺带覆盖了「切换模型后回合确实路由到新模型」这段链路。
    private func selectStubModel(_ model: String) {
        let selectModelButton = app.buttons["Select Model"]
        XCTAssertTrue(
            selectModelButton.waitForExistence(timeout: 20),
            "Action Bar 缺少模型选择按钮"
        )
        selectModelButton.click()

        let popover = element(identifier: Shell.modelPopover)
        XCTAssertTrue(
            popover.waitForExistence(timeout: 10),
            "模型选择弹窗未出现"
        )

        // UI 测试供应商 isLocal = true，因此它位于「本地」页签。
        let localSegment = app.radioButtons["Local"]
        XCTAssertTrue(
            localSegment.waitForExistence(timeout: 5),
            "供应商列表缺少 Local 页签"
        )
        localSegment.click()

        // 点击页签后列表要重新筛选，留一点稳定期再断言，避免读到切换前的快照。
        sleep(1)

        let providerRow = element(identifier: "lumi.model-selector.provider.ui-test")
        if !providerRow.waitForExistence(timeout: 5) {
            // 记录当前可见的供应商行，便于定位是「页签没切过去」还是「供应商没注册」。
            let rows = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "lumi.model-selector.provider."))
                .allElementsBoundByIndex
                .map { "\($0.identifier)=\($0.label)" }
            XCTFail("本地供应商列表缺少 UI Test。实际可见：\(rows)")
        }
        providerRow.click()

        let modelRow = element(identifier: "lumi.model-selector.model.\(model)")
        XCTAssertTrue(
            modelRow.waitForExistence(timeout: 5),
            "模型列表缺少 \(model)"
        )
        modelRow.click()

        // 选中模型会关闭弹窗；等它消失，避免与后续点击争抢命中测试。
        _ = popover.waitForNonExistence(timeout: 10)
        // 弹窗关闭后输入框需要重新拿回键盘焦点，否则紧随其后的 typeText 会落空。
        sleep(1)
    }

    /// 在输入框里输入文本并按 Return 发送。
    ///
    /// 用键盘发送而不是点按钮：按钮初始因 `canSend` 为 false 而不可用。
    @discardableResult
    private func typeAndSend(_ text: String) -> Bool {
        let editor = element(identifier: Shell.editor)
        guard editor.waitForExistence(timeout: 20) else { return false }
        editor.click()
        editor.typeText(text)
        editor.typeKey(.return, modifierFlags: [])
        return true
    }

    // MARK: - Tests

    /// choice 模式全链路：发问 → 问题卡片与选项出现 → 点选 → 恢复 → 桩收尾回复。
    ///
    /// 这是覆盖面最广的一条：它同时证明了挂起渲染、选项点击、恢复链路、
    /// 以及「答案真的回传给模型」四件事。
    ///
    /// 断言分层：
    /// 1. 回合发起后出现问题卡片，且问题正文与桩产出一致 → 挂起渲染生效；
    /// 2. 两个选项都出现（第二个带 description / badge）→ 选项列表渲染完整；
    /// 3. 点选后出现「已回答」回显 → 点击被受理；
    /// 4. 桩收尾正文出现 → 恢复链路跑通、答案已回传给模型。
    func testChoiceQuestionAppearsAndAnsweringResumesTurn() throws {
        waitForMainWindow()
        selectStubModel("ui-test-ask-user-choice")

        let prompt = "UI Testing Ask User Choice Probe"
        XCTAssertTrue(
            typeAndSend(prompt),
            "未找到聊天输入框（identifier=\(Shell.editor)）"
        )
        XCTAssertTrue(
            element(anyLabelOf: [prompt]).waitForExistence(timeout: 30),
            "用户消息未出现在时间线上，回合可能未启动"
        )

        // 断言 1：问题卡片出现，且问题正文是桩产出的固定文案。
        let card = element(identifier: Identifiers.card)
        XCTAssertTrue(
            card.waitForExistence(timeout: 40),
            """
            ask_user 问题卡片未出现（identifier=\(Identifiers.card)），\
            说明模型未发起工具调用，或工具未产生挂起点
            """
        )
        XCTAssertTrue(
            element(identifier: Identifiers.question).label.contains(Stub.choiceQuestion),
            "问题正文与桩产出的文案不一致"
        )

        // 断言 2：选项按钮全部渲染。
        let firstOption = element(identifier: Identifiers.option(0))
        let secondOption = element(identifier: Identifiers.option(1))
        XCTAssertTrue(
            firstOption.waitForExistence(timeout: 10),
            "第一个选项未出现（identifier=\(Identifiers.option(0))）"
        )
        XCTAssertTrue(
            secondOption.exists,
            "第二个选项未出现（identifier=\(Identifiers.option(1))）"
        )
        // 选项带 description 时会以合并的无障碍标签暴露出来。
        XCTAssertTrue(
            firstOption.label.contains(Stub.choiceAcceptedOption),
            "第一个选项文案与桩不一致，实际：\(firstOption.label)"
        )
        XCTAssertTrue(
            firstOption.label.contains(Stub.choiceAcceptedDescription),
            "带 description 的选项未渲染说明文案，实际：\(firstOption.label)"
        )

        // 断言 3：点击选项后界面回显「已回答」。
        firstOption.click()
        XCTAssertTrue(
            element(identifier: Identifiers.answered).waitForExistence(timeout: 15),
            """
            点击选项后未出现「已回答」回显（identifier=\(Identifiers.answered)），\
            说明点击未被受理
            """
        )

        // 断言 4：回合恢复并以桩收尾正文结束。
        //
        // 这是「答案确实回传给 LLM 并被接受」的确定性证据：桩只有在请求体里
        // 看到 role=tool 消息（即用户已回答）时才产出这段正文。
        XCTAssertTrue(
            element(anyLabelOf: [Stub.followUpResponse]).waitForExistence(timeout: 60),
            """
            回答后未渲染桩收尾回复「\(Stub.followUpResponse)」，\
            说明恢复链路未跑完或答案未回传给模型
            """
        )

        // 问题卡片应随挂起点清除而消失。
        XCTAssertFalse(
            element(identifier: Identifiers.answered).waitForExistence(timeout: 5),
            "回合完成后「已回答」回显仍残留"
        )
        XCTAssertTrue(
            element(identifier: "root.main").exists,
            "回答后主窗口消失，App 可能已崩溃"
        )
    }

    /// free_text 模式：输入框 + 提交按钮，回答后回合恢复。
    ///
    /// 与 choice 互补：覆盖「没有选项、只能自由输入」的渲染分支，以及
    /// 提交按钮的 `disabled` 判定（空内容不可提交）。
    func testFreeTextQuestionAcceptsTypedAnswerAndResumesTurn() throws {
        waitForMainWindow()
        selectStubModel("ui-test-ask-user-free-text")

        let prompt = "UI Testing Ask User Free Text Probe"
        XCTAssertTrue(typeAndSend(prompt), "未找到聊天输入框")

        let card = element(identifier: Identifiers.card)
        XCTAssertTrue(
            card.waitForExistence(timeout: 40),
            "free_text 问题卡片未出现"
        )

        let field = element(identifier: Identifiers.freeTextField)
        let submit = element(identifier: Identifiers.submitButton)
        XCTAssertTrue(
            field.waitForExistence(timeout: 10),
            "free_text 输入框未出现（identifier=\(Identifiers.freeTextField)）"
        )
        XCTAssertTrue(
            submit.exists,
            "free_text 提交按钮未出现（identifier=\(Identifiers.submitButton)）"
        )

        // 空内容时提交按钮必须不可用——否则会发出一个空答案并恢复回合。
        XCTAssertFalse(
            submit.isEnabled,
            "输入为空时提交按钮不应可用"
        )

        field.click()
        field.typeText(Stub.freeTextAnswer)

        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: submit)
        waitForExpectations(timeout: 15)

        submit.click()

        XCTAssertTrue(
            element(identifier: Identifiers.answered).waitForExistence(timeout: 15),
            "点击提交后未出现「已回答」回显"
        )
        XCTAssertTrue(
            element(anyLabelOf: [Stub.followUpResponse]).waitForExistence(timeout: 60),
            """
            free_text 回答后未渲染桩收尾回复「\(Stub.followUpResponse)」，\
            说明恢复链路未跑完或答案未回传给模型
            """
        )
    }

    /// yes_no 模式：两个固定选项，任选其一都能恢复回合。
    ///
    /// 覆盖「选项只有两个」这一最常见形态，并确认点击「否」同样能走通链路
    /// （答案内容不同不应影响恢复）。
    func testYesNoQuestionOptionResumesTurnWithEitherAnswer() throws {
        waitForMainWindow()
        selectStubModel("ui-test-ask-user-yes-no")

        let prompt = "UI Testing Ask User Yes No Probe"
        XCTAssertTrue(typeAndSend(prompt), "未找到聊天输入框")

        XCTAssertTrue(
            element(identifier: Identifiers.card).waitForExistence(timeout: 40),
            "yes_no 问题卡片未出现"
        )
        XCTAssertTrue(
            element(identifier: Identifiers.question).label.contains(Stub.yesNoQuestion),
            "问题正文与桩产出的文案不一致"
        )

        // yes_no 固定两个选项：点第二个（否），确认非「是」的答案同样能恢复。
        let secondOption = element(identifier: Identifiers.option(1))
        XCTAssertTrue(
            secondOption.waitForExistence(timeout: 10),
            "yes_no 的第二个选项未出现"
        )
        secondOption.click()

        XCTAssertTrue(
            element(identifier: Identifiers.answered).waitForExistence(timeout: 15),
            "点击选项后未出现「已回答」回显"
        )
        XCTAssertTrue(
            element(anyLabelOf: [Stub.followUpResponse]).waitForExistence(timeout: 60),
            """
            回答后未渲染桩收尾回复「\(Stub.followUpResponse)」，\
            说明恢复链路未跑完
            """
        )
    }

    /// 未提问时不应渲染问题卡片。
    ///
    /// 这条防止「卡片残留」类回归：底部固定区一旦在某次挂起后没被清掉，
    /// 就会在后续所有会话里持续显示一个无法回答的问题。
    func testNoQuestionCardWhenNoPendingAskUser() throws {
        waitForMainWindow()
        selectStubModel("ui-test-text")

        let prompt = "UI Testing Ask User Absent Probe"
        XCTAssertTrue(typeAndSend(prompt), "未找到聊天输入框")

        // 文本场景必定正常结束，且不会产生挂起点。
        XCTAssertTrue(
            element(anyLabelOf: ["UI Testing Reply"]).waitForExistence(timeout: 60),
            "普通回合未跑完，无法验证卡片不出现"
        )
        // 用快照式 exists（非 waitForExistence）：问题卡片若真的存在会立即命中；
        // 这里只需确认回合结束后没有残留卡片。
        XCTAssertFalse(
            element(identifier: Identifiers.card).exists,
            "没有挂起交互时不应出现问题卡片"
        )
    }
}

// MARK: - Helper

private extension XCUIElement {
    /// 等待元素从无到有（用于处理会话切换、卡片弹出等异步渲染）。
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
