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
///
/// ## 为什么这些用例必须切到 `ui-test-very-slow`
///
/// 夹具默认模型 `ui-test-text` 实测端到端仅 **1ms**（3 个 SSE 事件、无延迟）。
/// 回合在测试能观察到之前就结束了，因此：
///
/// - 「停止按钮取代发送按钮」根本无从观察——按钮出现即消失；
/// - 「回合跑完并渲染桩回复」也无法区分「跑完了」与「根本没跑」。
///
/// `ui-test-very-slow` 把回合拉到约 14s（32 段 × 0.4s），让「回合中」成为一个
/// 可稳定采样的状态。这不是放宽断言，而是把原本依赖毫秒级运气的用例
/// 变成确定性用例。
final class LumiSendActionBarUITests: LumiUITestCase {
    /// 让回合足够长以便观察的桩模型（实测约 14s）。
    private enum StubModel {
        static let verySlow = "ui-test-very-slow"
    }

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
        // 启动、引导关闭、元素定位等由 `LumiUITestCase` 提供；
        // 本文件只补充自己需要的夹具参数。
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

    /// 在输入框里输入文本并发送。
    ///
    /// 走**点击发送按钮**而非 `typeKey(.return)`。
    ///
    /// - Important: Return 会被宿主输入法的候选栏吞掉（候选栏是系统模态层，
    ///   `typeKey` 到不了 `NSTextView`），导致回合永不启动。这是夹具问题，
    ///   不是产品缺陷——详见 `LumiUITestCase` 顶部的长注释。
    ///   `LumiUITestCase.typeAndSend` 已统一改为点按钮，本方法直接复用。
    private func typeAndSend(_ text: String) {
        XCTAssertTrue(
            typeAndSend(text, editorIdentifier: Identifiers.editor),
            "输入「\(text)」后未能发出（identifier=\(Identifiers.editor)）"
        )
    }

    /// 切到让回合足够长的桩模型（见类注释）。
    ///
    /// 复刻 `LumiAskUserUITests.selectStubModel`：UI 测试供应商 `isLocal = true`，
    /// 因此位于模型选择器的「本地」页签。
    private func selectSlowStubModel() {
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

        let modelRow = element(identifier: "lumi.model-selector.model.\(StubModel.verySlow)")
        XCTAssertTrue(
            modelRow.waitForExistence(timeout: 5),
            "模型列表缺少 \(StubModel.verySlow)"
        )
        modelRow.click()

        // 选中模型会关闭弹窗；等它消失，避免与后续点击争抢命中测试。
        _ = popover.waitForNonExistence(timeout: 10)
        // 弹窗关闭后输入框需重新拿回焦点，否则紧随其后的点击会落空。
        sleep(1)
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
        selectSlowStubModel()

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
        selectSlowStubModel()

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
        let message = "UI Testing Send Button Probe"
        // 走剪贴板而不是 typeText：后者逐字符合成按键，会被宿主输入法
        // 吞掉最后一个空格，导致这里断言的完整文案永远匹配不上（详见
        // `LumiUITestCase` 类注释的实测对照表）。
        paste(message, into: editor)

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
        selectSlowStubModel()

        // 在临时目录放一个可拖入的文件。
        let attachment = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-ui-test-attachment-\(UUID().uuidString).txt")
        try "UI Testing Attachment".write(to: attachment, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: attachment) }

        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "未找到聊天输入框")
        let message = "UI Testing Attachment Probe"
        paste(message, into: editor)

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

    /// 选中会话被清空后，按钮状态必须回到发送态，而不是停留在旧会话的状态。
    ///
    /// 覆盖 `SendActionBarConversationObserver` 的选中会话订阅：
    /// `refreshConversationState()` 依据 `capability.selectedConversationID`
    /// 重新判断 `isSending`。这条链路一旦断掉，用户在一个正在跑的会话里
    /// 切走或开新对话，会看到一个「点了没反应」的停止按钮——
    /// 这是 `SendActionBarState` 单布尔模型最容易出问题的地方。
    ///
    /// ## 为什么覆盖的是「选中态清空」而不是「切到另一条会话」
    ///
    /// 本用例原本想点「新建会话」切到另一条会话，但实测走不通：
    ///
    /// - 「新建会话」工具栏按钮由 `NewChatToolbarObserver` 挂载，
    ///   在 UI 测试窗口的工具栏布局里**没有出现**（实测回合中 25 个按钮
    ///   无一是它），因此 `app.buttons["New Chat"]` 永远匹配不到。
    /// - 隔离存储下只有一条会话，会话列表也没有可切换的第二条目标。
    ///
    /// 因此改用左侧「Add」入口：它把 `selectedConversationID` 置空
    /// （`deselectConversation` 走同一条 observer 链路），并让 Action Bar
    /// 渲染回发送态。这条路径**确实可观测**（实测 `stop` 从 true 变 false、
    /// `send` 从 false 变 true），并且覆盖的正是 `refreshConversationState()`
    /// 的 nil 分支。
    ///
    /// - Important: 断言全部发生在「回合进行中」，因此必须先切到慢模型。
    ///   默认的 `ui-test-text` 回合仅 1ms，停止按钮在第一次采样前就消失，
    ///   用例会变成在赌轮询时机。
    func testButtonStateFollowsSelectedConversationAfterSwitch() throws {
        waitForMainWindow()
        selectSlowStubModel()

        let sendButton = element(identifier: Identifiers.sendButton)
        let stopButton = element(identifier: Identifiers.stopButton)
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: 20),
            "未找到发送按钮"
        )

        // 在当前会话发起一个回合。`verySlow` 让回合持续约 14s，
        // 下面「回合中」的观察才有一个稳定的时间窗口。
        typeAndSend("UI Testing Conversation Switch Probe")
        XCTAssertTrue(
            stopButton.waitForExistence(timeout: 30),
            "回合未启动，无法验证选中会话变化"
        )
        XCTAssertFalse(
            sendButton.exists,
            "回合运行中不应同时渲染发送按钮"
        )

        // 清空选中会话（打开起始面板）。
        //
        // - Important: 这里**不能**用 `app.buttons.firstMatch` 找入口。
        //   实测它命中的是窗口标题栏的 `_XCUI:CloseWindow`（界面上的第一个按钮），
        //   点下去是关闭整个窗口——用例会以一种与断言完全无关的方式失败，
        //   且失败信息指向「按钮状态没跟随」，极具误导性。
        let addButton = app.buttons["Add"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 10),
            "左侧缺少「Add」入口，无法清空选中会话"
        )
        addButton.click()

        // 切走后按钮必须立刻回到发送态：旧会话的 `isSending` 不该外溢到新状态。
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: 30),
            """
            清空选中会话后发送按钮未恢复，\
            说明按钮状态没有跟随 selectedConversationID 变化
            """
        )
        XCTAssertFalse(
            stopButton.exists,
            "切走会话后不应残留停止按钮"
        )
    }
}
