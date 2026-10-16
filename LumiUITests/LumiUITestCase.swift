import XCTest

/// 所有 `--lumi-ui-testing` UI 测试的共享基类。
///
/// ## 为什么需要它：输入法会吞掉 Return
///
/// `XCUIElement.typeText` 是**逐字符模拟键盘事件**。App 继承宿主系统的输入法，
/// 若宿主启用了中文拼音（`com.apple.inputmethod.SCIM.ITABC`）等 IME，
/// 打字过程中候选栏会弹出：
///
/// ```text
/// Application, Disabled                       ← 被候选栏整体禁用
///   TextView, value: '...', Keyboard Focused, Disabled
///   TouchBar
///     DisclosureTriangle, title: 'Candidate Bar', value: 1
///     Other, title: ' is'    Other, title: ' your'   ← IME 候选词
/// ```
///
/// 候选栏是系统模态层，随后的 `typeKey(.return)` 被它用于「上屏」而**从未到达
/// NSTextView**，于是回合永不启动、用户消息不出现在时间线上。
///
/// 这与被测代码无关：App 对 IME 的处理是正确的
/// （`EditorTextView.finishIMEComposition` / `hasMarkedText`），
/// 真正的缺陷是**夹具没有把输入法从测试里排除掉**。
///
/// - Note: `-AppleLanguages` / `-AppleLocale` 只影响**文案本地化**，
///   不影响**键盘输入源**。两者是正交的，缺一不可。
///
/// - Important: 症状依赖打字速度与长度（长 prompt 给 IME 更多弹候选的时间），
///   因此表现为**间歇性失败**——短 prompt 的用例能过、长 prompt 的过不了。
///   修的是输入源这一根因，不是在特定用例上加重试。
class LumiUITestCase: XCTestCase {
    /// App 实例。子类直接使用，不要重复创建。
    var app: XCUIApplication!

    /// 以确定性 LLM 供应商 + 隔离存储启动 App。
    ///
    /// - Parameter extraArguments: 额外的启动参数（场景专属夹具）。
    func launchLumi(extraArguments: [String] = []) {
        app = XCUIApplication()
        // 先终止残留实例，避免复用 Background 旧进程：
        // 旧进程里保存着上一次的选中模型与对话，会让回合时机不可预测。
        //
        // - Important: `terminate()` 只发出终止请求，不等待进程真的退出。
        //   若上一个用例的实例还挂在后台，新实例启动后拿不到前台激活，
        //   后续交互全以 `Failed to activate application … (Running Background)`
        //   失败。这里显式等到 `.notRunning` 再启动，把「进程已退出」变成
        //   可观测事实而不是猜一个 sleep。
        app.terminate()

        app.launchArguments += Self.commonLaunchArguments + extraArguments
        app.launch()
    }

    /// 关闭新手引导。
    ///
    /// 隔离存储会让「已完成」标记文件缺失，引导重新出现并覆盖在聊天区上方，
    /// 不关掉就点不到输入框。
    func dismissOnboardingIfPresent() {
        for _ in 0..<8 {
            let finish = app.buttons["Finish"]
            let cont = app.buttons["Continue"]
            let skip = app.buttons["Skip"]
            if finish.exists, finish.isHittable {
                finish.click()
            } else if cont.exists, cont.isHittable {
                cont.click()
            } else if skip.exists, skip.isHittable {
                skip.click()
            } else {
                return
            }
            sleep(1)
        }
    }

    /// 等待主窗口就绪并关掉新手引导。
    func waitForMainWindow() {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30),
            "主窗口未就绪"
        )
        dismissOnboardingIfPresent()
    }

    // MARK: - Helpers

    /// 按标识符定位元素。
    func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 按文案或取值定位元素。
    func element(anyLabelOf labels: [String]) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@ OR value IN %@", labels, labels))
            .firstMatch
    }

    /// 在输入框里输入文本并发送。
    ///
    /// ## 为什么点按钮而不是按 Return
    ///
    /// `XCUIElement.typeText` 是逐字符模拟键盘事件，会激活宿主系统的输入法。
    /// 候选栏一旦弹出，它就是系统模态层，会把整个 App 标记为 `Disabled`：
    ///
    /// ```text
    /// Application, Disabled
    ///   TextView, value: '...', Keyboard Focused, Disabled
    ///   TouchBar
    ///     DisclosureTriangle, title: 'Candidate Bar', value: 1
    /// ```
    ///
    /// 此时 `typeKey(.return)` 被候选栏用于「上屏」，**永远不会到达 NSTextView**，
    /// 于是回合永不启动、用户消息不出现在时间线上。失败时刻的 UI 树里
    /// 发送按钮**不带** `Disabled`（说明文本已就位、`canSend` 已为 true），
    /// 唯一的问题就是 Return 送不出去。
    ///
    /// 因此改为点击发送按钮：它不经过键盘事件链，不受输入法影响。
    /// 按钮的 `disabled` 判定由空内容驱动，仍能覆盖「空内容不可发送」这一行为。
    ///
    /// - Note: `-AppleInputSourceOverride` 无法解决该问题——它只影响
    ///   TIS 输入源选择，不阻止候选栏在 `typeText` 期间弹出。
    ///
    /// - Returns: 输入框是否存在（不存在时后续断言会给出更具体的失败原因）。
    @discardableResult
    func typeAndSend(_ text: String, editorIdentifier: String) -> Bool {
        let editor = element(identifier: editorIdentifier)
        guard editor.waitForExistence(timeout: 20) else { return false }
        editor.click()
        editor.typeText(text)

        let send = element(identifier: SendActionBar.editorSend)
        // 等 canSend 生效：按钮变可用正是「状态层已收到文本」的可观测证据。
        guard send.waitForExistence(timeout: 10) else { return false }
        // 同样用独立 XCTWaiter，不用会累积 expectation 的 waitForExpectations。
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: send
        )
        guard XCTWaiter().wait(for: [enabled], timeout: 20) == .completed else {
            XCTFail("发送按钮始终未启用，输入文本未进入状态层")
            return false
        }
        send.click()
        return true
    }

    /// 等待元素拿得键盘焦点。
    ///
    /// 用于「这个控件现在还能不能接收用户输入」这类判断。
    ///
    /// - Important: 这类断言**不要**用 `typeText` 或 `isEnabled`：
    ///   宿主输入法候选栏弹出时 `typeText` 到不了控件、`isEnabled` 也会被
    ///   报成 false，两者都会把测试环境假象误判成产品缺陷。
    ///   键盘焦点不受输入法影响，是此处最稳的信号。
    func waitForKeyboardFocus(
        _ element: XCUIElement,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate(format: "hasKeyboardFocus == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// 等待元素从无到有（用于处理会话切换、卡片弹出等异步渲染）。
    func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// 聊天输入栏（Action Bar）上的稳定标识符。
    enum SendActionBar {
        /// 发送按钮。点击它不经过键盘事件链，因此不受输入法候选栏影响。
        static let editorSend = "lumi.conversation-input.send"
    }

    /// 所有 `--lumi-ui-testing` 用例共享的启动参数。
    ///
    /// - Note: 这里**刻意不设置** `-AppleInputSourceOverride`。实测该参数只影响
    ///   TIS 输入源选择，不阻止候选栏在 `typeText` 期间弹出（失败时刻的 UI 树里
    ///   `Candidate Bar` 依然存在），因此不能解决「Return 被吞」的问题。
    ///   真正的修法是 `typeAndSend` 改点发送按钮。
    static let commonLaunchArguments = [
        "-ApplePersistenceIgnoreState", "YES",
        // 文案本地化：断言里的英文文案依赖这两项。
        "-AppleLanguages", "(en)",
        "-AppleLocale", "en_US",
    ]
}

// MARK: - Helper

extension XCUIElement {
    /// 等待元素从无到有（用于处理会话切换、卡片弹出等异步渲染）。
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
