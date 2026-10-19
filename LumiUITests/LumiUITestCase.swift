import XCTest
import AppKit

/// 所有 `--lumi-ui-testing` UI 测试的共享基类。
///
/// ## 为什么需要它：合成键盘事件不可靠
///
/// `XCUIElement.typeText` 是**逐字符派发合成键盘事件**，它有两个已被实测确认的缺陷，
/// 且**都与被测代码无关**：
///
/// 1. **尾随空格必丢**。宿主系统启用了中文拼音输入法时，`typeText` 的按键事件会
///    进入 IME 组合态，**最后一个空格被 IME 吞掉**——实测 `UI Testing Send Button Probe`
///    （28 字符）只进入 27 字符的 `UI Testing Send ButtonProbe`，`PROBE MESSAGE UNIQUE TEXT`
///    （25）进入 24，`Ask User Choice Probe`（21）进入 20，**每次都恰好少一个尾部空格**。
/// 2. **候选栏吞 Return**。候选栏是系统模态层，随后的 `typeKey(.return)` 被它用于
///    「上屏」而**从未到达 NSTextView**，于是回合永不启动。
///
/// - Important: 症状依赖打字速度与长度（长 prompt 给 IME 更多弹候选的时间），
///   因此表现为**间歇性失败**——短 prompt 的用例能过、长 prompt 的过不了。
///   修的是输入通道这一根因，不是在特定用例上加重试。
///
/// ## 本基类的对策：绕开键盘事件链
///
/// - **写入正文**：走 `NSPasteboard` + `⌘V`，绕开 IME 组合态。实测 3/3 完整无损。
/// - **发送**：点发送按钮，而不是 `typeKey(.return)`，绕开模态候选栏。
///
/// 两条路径都不经过 `typeText`，因此对上述两个输入法干扰免疫。
/// 粘贴需要 `⌘V`，它是一次性修饰键组合、瞬时完成，不会留下组合态残留。
///
/// - Note: `-AppleLanguages` / `-AppleLocale` 只影响**文案本地化**，
///   不影响**键盘输入源**。两者是正交的，缺一不可。
/// - Note: `-AppleInputSourceOverride` 无法解决该问题——它只影响
///   TIS 输入源选择，不阻止候选栏在 `typeText` 期间弹出。
class LumiUITestCase: XCTestCase {
    /// App 实例。子类直接使用，不要重复创建。
    var app: XCUIApplication!

    /// 以确定性 LLM 供应商 + 隔离存储启动 App。
    ///
    /// - Parameter extraArguments: 额外的启动参数（场景专属夹具）。
    func launchLumi(extraArguments: [String] = []) {
        app = XCUIApplication()
        // 先确保没有残留实例：旧进程里保存着上一次的选中模型与对话，
        // 会让回合时机不可预测；若它还挂在后台，新实例拿不到前台激活。
        //
        // - Important: `terminate()` 只发出终止请求，**不等待进程真的退出**。
        //   这里显式等到 `.notRunning`，把「旧进程已退出」变成可观测事实，
        //   而不是交给一个猜出来的 sleep。
        //
        //   症状：新实例起来后激活失败，后续每次交互都报
        //   `Failed to activate application … (Running Background)`，
        //   或元素处于 `Not Hittable`。它表现为随机的「某个元素突然找不到」，
        //   极易被误判成产品缺陷。
        terminateAppAndWait()

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

    /// 等待 App 进程彻底退出，必要时先请求终止。
    ///
    /// `terminate()` 是异步的：它发出终止请求后立刻返回，进程可能还在
    /// 清理窗口与写盘。直接 `launch()` 新实例会撞上仍在退出的旧进程，
    /// 导致激活失败或交互落在错误的目标上。
    ///
    /// 子类的 `tearDownWithError` 必须调用它而不是裸 `terminate()`，
    /// 否则「上一个用例还在退出」会泄漏成「下一个用例偶发失败」——
    /// 这种失败点随机漂移，极难归因。
    ///
    /// - Important: 用 `wait(for:)` 而不是固定 `sleep`：固定睡眠要么不够
    ///   （问题复现），要么白白拖慢每个用例。这里等的是真实状态变化。
    func terminateAppAndWait(timeout: TimeInterval = 10) {
        guard app.state != .notRunning else { return }
        app.terminate()
        let stopped = NSPredicate(format: "state == %d", XCUIApplication.State.notRunning.rawValue)
        let expectation = XCTNSPredicateExpectation(predicate: stopped, object: app)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail(
                """
                App 未在 \(Int(timeout))s 内退出（当前状态：\(app.state.rawValue)）。\
                后续交互会失败在「无法激活应用」而非真实断言上，请勿据此判定产品缺陷。
                """
            )
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

    /// label 或 value **包含**指定片段的元素。
    ///
    /// 用于文案带动态后缀的场景（如「执行了3个步骤 · 5秒」），
    /// 或需要用稳定前缀定位会话标题 / 消息正文。
    func element(containingLabel fragment: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(
                NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", fragment, fragment)
            )
            .firstMatch
    }

    /// 在输入框里输入文本并发送。
    ///
    /// ## 为什么走剪贴板而不是 `typeText`
    ///
    /// `XCUIElement.typeText` 是逐字符派发合成键盘事件，会进入宿主输入法（中文拼音）
    /// 的组合态，**必然丢掉最后一个空格**。实测三组对照：
    ///
    /// | 写入方式 | 期望 | 实际 |
    /// |---|---|---|
    /// | `typeText` | `UI Testing Send Button Probe`（28） | `UI Testing Send ButtonProbe`（27）❌ |
    /// | `typeText` | `PROBE MESSAGE UNIQUE TEXT`（25） | `PROBE MESSAGE UNIQUETEXT`（24）❌ |
    /// | 剪贴板粘贴 | 以上全部 | **完整无损** ✅ |
    ///
    /// 丢一个尾部空格会让「按完整文案断言消息是否上屏」的用例**必然失败**，
    /// 且失败现象极具误导性——界面上的用户消息明明在，内容却对不上，
    /// 很容易被误判成渲染缺陷或元素定位失败。
    ///
    /// ## 为什么点按钮而不是按 Return
    ///
    /// 候选栏是系统模态层，`typeKey(.return)` 会被它用于「上屏」而**永远不会到达
    /// NSTextView**，于是回合永不启动。点击发送按钮不经过键盘事件链，不受影响。
    /// 按钮的 `disabled` 判定由空内容驱动，仍能覆盖「空内容不可发送」这一行为。
    ///
    /// - Returns: 是否成功写入并点下发送（失败时后续断言会给出更具体的原因）。
    @discardableResult
    func typeAndSend(_ text: String, editorIdentifier: String) -> Bool {
        let editor = element(identifier: editorIdentifier)
        guard editor.waitForExistence(timeout: 20) else { return false }
        paste(text, into: editor)

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

    /// 通过剪贴板把文本写入控件。
    ///
    /// 为什么不校验返回值：AX 快照里长文本的 `value` 会被**截断显示**
    /// （例如 `value: 'UI Testing Send Button Probe'` 显示成
    /// `value: 'UI Testing Send Button Pr…'`），那是快照的显示缩写，
    /// 不是控件真实内容。用它做全等比对会对长文案一律误报。
    ///
    /// 因此这里只负责「把文本送进去」，写入是否成功由调用方后续断言去判定——
    /// `typeAndSend` 里等发送按钮变为可用，那才是真正可信的信号。
    func paste(_ text: String, into element: XCUIElement) {
        element.click()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // 剪贴板写入到 App 收到 ⌘V 之间留一个稳定期。
        // `⌘V` 是一次性组合、不进入 IME 组合态，但仍需要事件送达的时间。
        sleep(1)
        element.typeKey("v", modifierFlags: .command)
        sleep(1)
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
