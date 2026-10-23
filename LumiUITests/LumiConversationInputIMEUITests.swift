import XCTest

/// 中文拼音输入法（IME）下的输入响应性 UI 测试。
///
/// ## 这组用例补的是哪块缺口
///
/// 整个 UI 测试套件**刻意把输入法切到英文 ASCII**（见 `LumiUITestCase`）：
/// 中文输入法下 `typeText` 会丢尾部空格，历史上因此产生过一批莫名其妙的失败。
///
/// 代价是**中文输入路径从来没有被端到端测过**。而用户恰恰是在这条路径上
/// 报告「输入不跟手」。这组用例把输入法切回中文拼音，覆盖两件事：
///
/// 1. **功能正确性**：拼音能组合成汉字并进入草稿状态。
/// 2. **响应性**：组合态（拼音还在缓冲区里）不得污染草稿、不得把界面卡住。
///
/// ## 与单元测试的分工
///
/// `ChatInputIMECompositionTests`（包内单元测试）量的是「应用侧处理耗时」，
/// 排除了 XCUITest 自身的往返开销，结论精确但覆盖面窄。
/// 这里量的是端到端：用户按键 → 界面反映出来。开销更大，但包含真实链路上的
/// 所有环节（IME 组合态、SwiftUI 失效广播、AX 快照）。
///
/// ## 为什么断言用「发送按钮是否可用」而不是「输入框里有没有字」
///
/// IME 组合态期间，marked text **本来就该显示在编辑器里**——那是候选词的
/// 正常呈现，不是缺陷。真正要防的是它被当成正文写进了状态层。
/// 「发送按钮是否可用」正好是「草稿状态层收没收到正文」的可观测证据。
final class LumiConversationInputIMEUITests: LumiUITestCase {
    /// 与 `ChatInputEditorView` / `SendActionBarAccessibility` 保持一致。
    private enum Identifiers {
        static let editor = "lumi.conversation-input.editor"
        static let sendButton = "lumi.conversation-input.send"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(
            extraArguments: [
                // 确定性 LLM 供应商 + 隔离存储。
                "--lumi-ui-testing",
                "--lumi-ui-testing-isolated-storage",
            ],
            // 与其余 UI 用例相反：这里要留在中文拼音输入法上。
            inputSource: .chinesePinyin
        )
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Tests

    /// 组合态（拼音还在缓冲区里）不得写进草稿状态。
    ///
    /// 这是「中文输入不跟手」最常见的产品级成因：一旦组合态被当成正文上报，
    /// 每个按键都会触发一次 SwiftUI 失效广播，输入框与附件预览整段重建。
    /// 这里从界面侧验证它没发生——单元测试验证的是同一条不变式，
    /// 但那是绕过了 IME 与真实输入框的。
    func testChinesePinyinCompositionStaysOutOfDraftUntilCommit() throws {
        try XCTSkipUnless(
            didSwitchInputSource,
            "本机没有可用的中文拼音输入法，用例测不到目标行为，跳过"
        )
        waitForMainWindow()

        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "未找到聊天输入框")
        let sendButton = element(identifier: Identifiers.sendButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

        editor.click()
        XCTAssertTrue(waitForKeyboardFocus(editor), "输入框未获得键盘焦点")

        // 只打拼音，不上屏。中文输入法会把它收进组合态缓冲区。
        editor.typeText("nihao")

        let observed = (editor.value as? String) ?? ""
        XCTAssertFalse(
            sendButton.isEnabled,
            """
            IME 组合态期间发送按钮已可用，说明拼音被当成了正文写进草稿状态。\
            此时输入框内容为「\(observed)」
            """
        )
    }

    /// 上屏后汉字进入输入框并驱动状态层，端到端耗时在预算内。
    ///
    /// 这里的耗时是用户真正能感知的那个：从按下最后一个键，到界面把结果
    /// 反映出来。测得的数字包含 XCUITest 自身的往返开销，因此预算取得宽松；
    /// 真正的意义是「没有卡死」——一旦主线程被占住，AX 快照会停滞，
    /// 等待时间会直接顶到超时。
    func testChinesePinyinCommitsIntoEditorWithinLatencyBudget() throws {
        try XCTSkipUnless(
            didSwitchInputSource,
            "本机没有可用的中文拼音输入法，用例测不到目标行为，跳过"
        )
        waitForMainWindow()

        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "未找到聊天输入框")
        let sendButton = element(identifier: Identifiers.sendButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

        editor.click()
        XCTAssertTrue(waitForKeyboardFocus(editor), "输入框未获得键盘焦点")

        let started = Date()
        // 尾部空格会被中文输入法用于「上屏」——这正是 `UITestInputSource`
        // 记录的实测行为（英文输入法下这个空格会原样落进输入框）。
        editor.typeText("nihao ")
        let typed = Date()

        // 上屏后草稿非空，发送按钮随之可用。
        let enabled = NSPredicate(format: "enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabled, object: sendButton)
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: 20)
        let elapsed = Date().timeIntervalSince(started)

        print(
            """
            ── 中文拼音输入端到端耗时 ──────────────────────────
            合成按键耗时：\(String(format: "%.3f", typed.timeIntervalSince(started)))s
            到界面反映可用：\(String(format: "%.3f", elapsed))s
            ─────────────────────────────────────────────────────
            """
        )

        XCTAssertEqual(
            waitResult,
            .completed,
            "上屏后发送按钮始终未启用，说明汉字没有进入草稿状态"
        )
        XCTAssertLessThan(
            elapsed,
            5.0,
            "上屏到界面响应耗时 \(String(format: "%.3f", elapsed))s，超出 5s 预算"
        )

        let value = (editor.value as? String) ?? ""
        XCTAssertTrue(
            containsHanCharacter(value),
            "上屏后输入框里没有汉字，实际内容为「\(value)」"
        )
    }

    // MARK: - Helpers

    /// 判断字符串里是否含汉字（中日韩统一表意文字）。
    ///
    /// 只认汉字不认标点：输入法上屏后至少应有一个汉字落进输入框。
    private func containsHanCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
        }
    }
}
