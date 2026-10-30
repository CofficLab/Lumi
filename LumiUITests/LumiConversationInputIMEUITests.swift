import XCTest

/// 输入框的端到端响应性 UI 测试。
///
/// ## 这组用例补的是哪块缺口
///
/// 整个 UI 测试套件**刻意把输入法切到英文 ASCII**（见 `LumiUITestCase`）：
/// 中文输入法下 `typeText` 会丢尾部空格，历史上因此产生过一批莫名其妙的失败。
///
/// 代价是**中文输入路径从来没有被端到端测过**。而用户恰恰是在这条路径上
/// 报告「输入不跟手」。这组用例分两层：
///
/// 1. **输入法无关**（`testTypingStaysResponsiveEndToEnd`）：任何输入法下
///    「按键 → 界面反映出来」的端到端耗时。这条**必须始终可跑**——它是
///    「输入框跟不跟手」最直接的度量。
/// 2. **中文输入法专属**（两条 `ChinesePinyin` 用例）：组合态不污染草稿、
///    上屏后汉字进入输入框。
///
/// ## 跳过与失败的边界
///
/// 中文用例把**环境问题**和**产品问题**分开：
///
/// - **环境**：macOS 的输入源属于当前活动应用，App 激活后系统会把「该 App
///   记住的输入源」抢回前台。抢回英文布局时，IME 根本不接管，合成按键被
///   直接落成 ASCII 字符——这是环境状态，不是产品缺陷。此时**跳过**并说明原因。
/// - **产品**：输入法确实已是中文拼音，汉字却仍进不了输入框——这才是失败。
///
/// 判据是「打字那一刻的当前输入源」，与环境无关、可直接观测。
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

    /// 中文拼音输入法在该 App 里生效时，当前输入源 ID 的前缀。
    private static let chinesePinyinPrefix = "com.apple.inputmethod.SCIM"

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
        try activateChinesePinyin()

        let editor = try prepareEditor()
        let sendButton = element(identifier: Identifiers.sendButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

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
    func testChinesePinyinCommitsIntoEditorWithinLatencyBudget() throws {
        try XCTSkipUnless(
            didSwitchInputSource,
            "本机没有可用的中文拼音输入法，用例测不到目标行为，跳过"
        )
        waitForMainWindow()
        try activateChinesePinyin()

        let editor = try prepareEditor()
        let sendButton = element(identifier: Identifiers.sendButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

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

        let value = (editor.value as? String) ?? ""
        print(
            """
            ── 中文拼音输入端到端耗时 ──────────────────────────
            合成按键耗时：\(String(format: "%.3f", typed.timeIntervalSince(started)))s
            到界面反映可用：\(String(format: "%.3f", elapsed))s
            打字时当前输入源：\(UITestInputSource.currentInputSourceID ?? "nil")
            上屏后输入框内容：「\(value)」
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
        XCTAssertTrue(
            containsHanCharacter(value),
            """
            输入源已是中文拼音（\(UITestInputSource.currentInputSourceID ?? "nil")），\
            上屏后输入框里却没有汉字，实际内容为「\(value)」。\
            这说明 IME 接管了输入却没有产出汉字，属于产品问题而非环境问题。
            """
        )
    }

    // MARK: - Helpers

    /// 让中文拼音输入法在**本 App**里生效，并在不生效时跳过用例。
    ///
    /// - Important: 必须在 App 激活**之后**切换。macOS 的输入源属于当前活动
    ///   应用：启动前切换改的是当时前台应用的输入源，随后新起的 Lumi 进程
    ///   会拿回它自己记住的输入源。详见 `applyInputSourceStrategy()`。
    ///
    /// - Throws: 输入法没能在该 App 里生效时抛出 `XCTSkip`。
    private func activateChinesePinyin() throws {
        app.activate()
        // 激活是异步的：AppKit 会在激活完成后把「本 App 记住的输入源」
        // 应用到当前输入源，把我们切过去的输入法又打回英文布局。
        // 等它真的成为前台再切。
        let activated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "state == %d", XCUIApplication.State.runningForeground.rawValue),
            object: app
        )
        _ = XCTWaiter().wait(for: [activated], timeout: 15)

        applyInputSourceStrategy()

        let current = UITestInputSource.currentInputSourceID ?? ""
        try XCTSkipUnless(
            current.hasPrefix(Self.chinesePinyinPrefix),
            """
            该 App 的当前输入源是「\(current)」而不是中文拼音，IME 不会接管组合态。\
            这是 macOS「按应用记住输入源」的行为，属环境状态，用例跳过。\
            （此时合成按键会被直接落成 ASCII 字符，看起来像中文输入法坏了。）
            """
        )
    }

    /// 点开输入框并等到它真正拿到键盘焦点。
    ///
    /// IME 只有在控件位于输入回路里（即持有键盘焦点）时才会接管合成按键；
    /// 没有焦点时按键会被直接落成字符，组合态根本不出现。
    private func prepareEditor() throws -> XCUIElement {
        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "未找到聊天输入框")
        XCTAssertTrue(editor.isHittable, "聊天输入框不可点击")
        editor.click()
        XCTAssertTrue(
            waitForKeyboardFocus(editor, timeout: 20),
            """
            输入框未获得键盘焦点（IME 需要焦点才会接管组合态）。\
            当前输入源为「\(UITestInputSource.currentInputSourceID ?? "nil")」
            """
        )
        return editor
    }

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

/// 输入框的端到端响应性（与输入法无关）。
///
/// ## 为什么单独一个类
///
/// 这条用例量的是「按键 → 界面反映出来」的端到端延迟，与输入法无关：
/// App 侧的逐键路径在组合态与普通输入下完全一致。因此它用**默认的英文
/// ASCII 布局**跑，不必迁就 IME。
///
/// 放在中文用例那个类里会有两个副作用：① 每个 ASCII 字符也要走一遍
/// IME 组合态，合成事件数量翻倍；② 中文拼音下 `typeText` 的尾部空格会被
/// IME 吃掉，探针文本的长度对不上。
///
/// ## 为什么探针文本要短
///
/// `typeText` 是逐字符派发合成事件的，每个字符都要等 App 回到空闲。
/// 文本越长，XCUITest 的事件合成越容易超时（`Failed to synthesize event:
/// Timed out while synthesizing event`）——那在机器负载高时是**测试环境**
/// 的问题，不是产品的。断言只需要「有一段非空文本进入了草稿状态」。
final class LumiConversationInputResponsivenessUITests: LumiUITestCase {
    /// 与 `ChatInputEditorView` / `SendActionBarAccessibility` 保持一致。
    private enum Identifiers {
        static let editor = "lumi.conversation-input.editor"
        static let sendButton = "lumi.conversation-input.send"
    }

    /// 探针文本。够短，避免事件合成超时。
    private static let probe = "IME Probe"

    override func setUpWithError() throws {
        continueAfterFailure = false
        // 默认即英文 ASCII 布局：这条用例与输入法无关。
        launchLumi(extraArguments: [
            "--lumi-ui-testing",
            "--lumi-ui-testing-isolated-storage",
        ])
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    /// 「按键 → 界面反映出来」的端到端耗时必须落在预算内。
    ///
    /// 这是用户真正能感知的那个延迟。测得的数字包含 XCUITest 自身的逐字符
    /// 往返开销，所以预算取得宽松；真正的意义是「没有卡死」——一旦主线程被
    /// 占住，AX 快照会停滞，等待时间会直接顶到超时。
    func testTypingStaysResponsiveEndToEnd() throws {
        waitForMainWindow()

        let editor = element(identifier: Identifiers.editor)
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "未找到聊天输入框")
        let sendButton = element(identifier: Identifiers.sendButton)
        XCTAssertTrue(sendButton.waitForExistence(timeout: 20), "未找到发送按钮")

        editor.click()
        XCTAssertTrue(waitForKeyboardFocus(editor, timeout: 20), "输入框未获得键盘焦点")

        let started = Date()
        editor.typeText(Self.probe)
        let typed = Date()

        // 状态层收到文本 → 发送按钮变为可用。
        let enabled = NSPredicate(format: "enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabled, object: sendButton)
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: 20)
        let elapsed = Date().timeIntervalSince(started)

        print(
            """
            ── 输入框端到端耗时 ────────────────────────────────
            探针：\(Self.probe)（\(Self.probe.count) 字符）
            合成按键耗时：\(String(format: "%.3f", typed.timeIntervalSince(started)))s
            到界面反映可用：\(String(format: "%.3f", elapsed))s
            打字时当前输入源：\(UITestInputSource.currentInputSourceID ?? "nil")
            ─────────────────────────────────────────────────────
            """
        )

        XCTAssertEqual(
            waitResult,
            .completed,
            "输入后发送按钮始终未启用，说明文本没有进入草稿状态"
        )
        XCTAssertLessThan(
            elapsed,
            5.0,
            "输入到界面响应耗时 \(String(format: "%.3f", elapsed))s，超出 5s 预算"
        )
    }
}
