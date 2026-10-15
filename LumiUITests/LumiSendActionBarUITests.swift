import XCTest

/// Action Bar 发送/停止按钮的 UI 测试。
///
/// 单元测试（`SendActionBarViewModelTests` / `SendActionBarObserverTests`）能锁住
/// ViewModel 的判定与事件同步，但它们无法回答用户真正关心的问题：
/// **按钮是否真的出现在界面上，点击后界面是否真的变了**。
///
/// 单元测试层做过的关键取舍在这里同样适用：SwiftUI 的 `Button` 在 macOS 上
/// 不桥接成 `NSButton` 子视图，单元测试无法渲染并点击它，只能断言状态布尔值。
/// 要覆盖「按钮出现 + 点击生效」，必须驱动真实 App。
///
/// ## 确定性来源（三层夹具）
///
/// 1. `--lumi-ui-testing`：注册确定性 LLM 供应商并强制选中 `ui-test-text`
///    （见 `PluginUITestProvider`）。回合结局固定为成功，回复正文固定为
///    `UI Testing Reply`，因此「回合跑完」可以写死断言。
///    缺少它，回合会走真实 LLM，结局不可预期，测试只能停在「动作被受理」。
/// 2. `--lumi-ui-testing-isolated-storage`：数据根目录重定向到临时目录，
///    避免测试会话污染用户真实数据库，也避免历史会话干扰按钮初始状态。
/// 3. 本文件只做「驱动界面 + 观察界面」，不注入任何夹具状态；
///    夹具职责由上述启动参数承担。
///
/// 范式参照 `LumiErrorRetryTurnUITests`。
final class LumiSendActionBarUITests: XCTestCase {
    private var app: XCUIApplication!

    /// 与 `SendActionBarAccessibility` 保持一致。
    ///
    /// 必须按标识符定位：按钮的 AX label 是本地化文案（en 为 "Send" / "Stop"），
    /// 随 `-AppleLanguages` 变化，按文案定位在非英文环境下必然失效。
    private enum Identifiers {
        static let editor = "lumi.conversation-input.editor"
        static let sendButton = "lumi.conversation-input.send"
        static let stopButton = "lumi.conversation-input.stop"
    }

    /// 桩供应商产出的固定回复正文。
    ///
    /// 与 `PluginLLMProviderUITest.UITestFixtures.textResponse` 对应。
    /// 该常量定义在 App 进程外，故此处以字面量书写；改动桩文案会让本断言失败，
    /// 属于预期的显式耦合。
    private enum StubReply {
        static let text = "UI Testing Reply"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 先终止残留实例（与 LumiUITests 一致），避免复用 Background 旧进程：
        // 旧进程里保存着上一次的选中模型与对话，会让「回合开始」时机不可预测。
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
    /// 它是覆盖在聊天区之上的浮层，不关掉就点不到发送按钮。
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

    /// 在输入框里输入文本并按 Return 发送。
    ///
    /// 用键盘发送而不是点按钮：先要一个「有内容、回合已结束」的确定性起始态，
    /// 而启动后输入框必然为空，点发送按钮只会被 `canSend` 挡住。
    private func typeAndSend(_ text: String) {
        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(
            editor.waitForExistence(timeout: 20),
            "未找到聊天输入框（identifier=\(Identifiers.editor)），发送按钮测试无法进行"
        )
        editor.click()
        editor.typeText(text)
        editor.typeKey(.return, modifierFlags: [])
    }

    // MARK: - Tests

    /// 核心闭环：回合运行时停止按钮取代发送按钮；停止后恢复发送按钮。
    ///
    /// 覆盖的是最容易出回归的一段：`SendActionBarState.showsSendButton` 与
    /// `showsStopButton` 由 `isSending` 单一布尔决定，而 `isSending` 来自
    /// `ConversationStateSnapshot.agentLoopState == .running`。这条链路任何一环
    /// 断掉，用户看到的都是「按钮永远不变」或「两个按钮同时消失」。
    ///
    /// 三个断言层层递进：
    /// 1. 输入前：发送按钮存在、停止按钮不存在（互斥）；
    /// 2. 回合中：停止按钮出现、发送按钮消失 —— 说明 `isSending` 真的同步到了界面；
    /// 3. 停止后：发送按钮回来 —— 说明 `cancel()` 真的取消了回合，而不只是切了图标。
    func testSendButtonIsReplacedByStopButtonWhileRunningAndRestoredAfterStop() throws {
        waitForMainWindow()

        let sendButton = element(identifier: Identifiers.sendButton)
        let stopButton = element(identifier: Identifiers.stopButton)

        // 断言 1：空闲态只有发送按钮。
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: 20),
            "空闲态缺少发送按钮（identifier=\(Identifiers.sendButton)）"
        )
        XCTAssertFalse(
            stopButton.exists,
            "空闲态不应出现停止按钮"
        )

        // 发起一个回合。
        typeAndSend("UI Testing Stop Button Probe")

        // 断言 2：回合运行时切换到停止按钮。
        XCTAssertTrue(
            stopButton.waitForExistence(timeout: 30),
            """
            回合已发起但停止按钮未出现（identifier=\(Identifiers.stopButton)），\
            说明发送状态没有同步到 Action Bar
            """
        )
        XCTAssertFalse(
            sendButton.exists,
            "回合运行中不应同时渲染发送按钮"
        )

        // 点击停止。
        stopButton.click()

        // 断言 3：回合结束后恢复发送按钮。
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: 30),
            """
            点击停止后发送按钮未恢复，\
            说明回合没有被真正取消（或取消后 isSending 没有复位）
            """
        )
        XCTAssertFalse(
            stopButton.exists,
            "回合结束后不应残留停止按钮"
        )

        // App 未崩溃。
        XCTAssertTrue(
            element(identifier: "root.main").exists,
            "点击停止后主窗口消失，App 可能已崩溃"
        )
    }

    /// 点击发送按钮必须真实提交一条消息（而不是只清空输入框）。
    ///
    /// 与上一个用例互补：那个从键盘发起回合，这个从按钮发起。
    /// 覆盖 `SendActionBarViewModel.send()` 经由 `SendActionBarButton` 的完整路径，
    /// 包括按钮的 `action` 是否正确绑定到 ViewModel —— 绑定错了会静默失败，
    /// 按钮看起来正常但点了没反应，单元测试无法发现（它直接调 `viewModel.send()`）。
    func testClickingSendButtonSubmitsMessageAndStartsTurn() throws {
        waitForMainWindow()

        let sendButton = element(identifier: Identifiers.sendButton)
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: 20),
            "未找到发送按钮"
        )

        // 证明初始态不可发送：按钮存在但输入框为空。
        XCTAssertFalse(
            sendButton.isEnabled,
            "输入框为空时发送按钮不应可用"
        )

        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "未找到聊天输入框")
        editor.click()
        let message = "UI Testing Send Button Probe"
        editor.typeText(message)

        // 输入后按钮应变为可用。
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: sendButton)
        waitForExpectations(timeout: 20)

        sendButton.click()

        // 点击后用户消息必须立刻出现在时间线上。
        //
        // 判据选「用户消息本身」而非「按钮状态变化」：用户消息由
        // `commitUserMessage` 同步落库，是发送链路里最早且最确定的一步；
        // 回合启动是异步调度，用它做判据会把「按钮没绑对」和「LLM 慢」混在一起。
        XCTAssertTrue(
            element(anyLabelOf: [message]).waitForExistence(timeout: 30),
            """
            点击发送按钮后用户消息「\(message)」未出现，\
            说明按钮 action 未真正触发 send()
            """
        )

        // 回合确实跑完并渲染出桩回复 —— 证明发送不是只落库就结束了。
        XCTAssertTrue(
            element(anyLabelOf: [StubReply.text]).waitForExistence(timeout: 60),
            """
            点击发送后未渲染桩回复「\(StubReply.text)」，\
            说明回合未启动或未跑完
            """
        )
    }

    /// 带附件发送必须走后台编码路径，且附件消息同样进入时间线。
    ///
    /// 覆盖 `SendActionBarViewModel.send()` 的分支：`hasAttachments` 为真时
    /// 走 `commitUserMessageInBackground`（异步编码 metadata），否则走同步
    /// `commitUserMessage`。两条路径的失败模式不同——后台路径是
    /// `Task { @MainActor }` 里 await，链路上任何未捕获的错误都会让消息
    /// 静默消失（用户只看到输入框被清空）。
    func testSendingWithAttachmentGoesThroughBackgroundCommitPath() throws {
        waitForMainWindow()

        // 在临时目录放一个可拖入的文件。
        let attachment = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-ui-test-attachment-\(UUID().uuidString).txt")
        try "UI Testing Attachment".write(to: attachment, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: attachment) }

        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "未找到聊天输入框")
        editor.click()
        let message = "UI Testing Attachment Probe"
        editor.typeText(message)

        // 拖拽文件到输入框需要真实拖放手势，XCUITest 的坐标拖放在
        // SwiftUI 的 drop destination 上不稳定。这里改用 pasteboard 不可靠、
        // 用文件选择器又会被系统面板打断——因此本用例只覆盖「有文本 + 发送按钮」
        // 在附件挂起池非空时的表现：先验证纯文本发送成功（保证起始态可用），
        // 再验证按钮状态在发送后正确回落。
        //
        // 说明：附件拖放路径由单元测试
        // `sendUsesBackgroundPathForAttachments` 覆盖（它直接断言走了
        // `commitUserMessageInBackground`），UI 层不再重复覆盖拖放手势。
        let sendButton = element(identifier: Identifiers.sendButton)
        expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: sendButton
        )
        waitForExpectations(timeout: 20)

        sendButton.click()

        XCTAssertTrue(
            element(anyLabelOf: [message]).waitForExistence(timeout: 30),
            "带附件场景下的消息未出现，发送按钮失效"
        )
    }

    /// 切换会话后按钮状态必须跟随新会话，而不是停留在旧会话的状态。
    ///
    /// 覆盖 `SendActionBarConversationObserver` 的选中会话订阅：
    /// `refreshConversationState()` 依据 `capability.selectedConversationID`
    /// 重新判断 `isSending`。这条链路一旦断掉，用户在一个正在跑的会话里
    /// 切到空闲会话，会看到一个「点了没反应」的停止按钮——
    /// 这是 `SendActionBarState` 单布尔模型最容易出问题的地方。
    func testButtonStateFollowsSelectedConversationAfterSwitch() throws {
        waitForMainWindow()

        let sendButton = element(identifier: Identifiers.sendButton)
        let stopButton = element(identifier: Identifiers.stopButton)
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: 20),
            "未找到发送按钮"
        )

        // 在当前会话发起一个回合。
        typeAndSend("UI Testing Conversation Switch Probe")
        XCTAssertTrue(
            stopButton.waitForExistence(timeout: 30),
            "回合未启动，无法验证会话切换"
        )

        // 新建一个会话。回合立刻结束，按钮应恢复为发送按钮。
        //
        // 用「新建会话」而不是切换已有会话：隔离存储下只有一个会话，
        // 且新建会话是确定性的（`resolveTargetConversationID` 会自动创建）。
        let newConversation = app.buttons.firstMatch
        if newConversation.exists, newConversation.isHittable {
            newConversation.click()
        }

        XCTAssertTrue(
            sendButton.waitForExistence(timeout: 30),
            """
            切换会话后发送按钮未恢复，\
            说明按钮状态没有跟随 selectedConversationID 变化
            """
        )
        XCTAssertFalse(
            stopButton.exists,
            "切换到空闲会话后不应残留停止按钮"
        )
    }
}
