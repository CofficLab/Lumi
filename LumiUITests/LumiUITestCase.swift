import XCTest
import AppKit

/// 所有 `--lumi-ui-testing` UI 测试的共享基类。
///
/// ## 输入通道：为什么用 `typeText` 而不是剪贴板
///
/// 写入正文走 `typeText`（模拟用户逐字打字），**不走** `NSPasteboard` + `⌘V`。
/// 理由是「像用户」：用户往输入框里打字走的就是这条链路，而 ⌘V 模拟的是
/// 「复制一段文字粘过来」，那是**另一条**产品功能。输入框对绝大多数用例只是
/// 「有文本、按钮可用」的前置条件载体，用 ⌘V 去搭这个前置条件，等于让一条
/// 无关路径承担失败的 blame，同时还要占用剪贴板（用户的全局状态）。
///
/// 历史上确实用过 ⌘V，原因是 `typeText` 在中文输入法下会**丢掉最后一个空格**：
/// 合成按键进入 IME 组合态，空格被 IME 用于「上屏」而没进控件。实测三组对照：
///
/// | 写入方式 | 期望 | 实际 |
/// |---|---|---|
/// | `typeText`（中文输入法下） | `UI Testing Send Button Probe`（28） | `…Probe`（27）❌ |
/// | `typeText`（中文输入法下） | `PROBE MESSAGE UNIQUE TEXT`（25） | `PROBE MESSAGE UNIQUETEXT`（24）❌ |
/// | 剪贴板粘贴 | 以上全部 | 完整无损 ✅ |
///
/// **现在 `launchLumi` 会在启动前把输入源切到英文 ASCII 布局**（tearDown 还原），
/// IME 组合态不再出现，这条路径恢复正常。切换与还原的实现见
/// `UITestInputSource`，那条实测对照表也留在那里作为依据。
///
/// 发送仍然点发送按钮而不是 `typeKey(.return)`：候选栏是系统模态层，
/// Return 会被它用于「上屏」而永不送达 NSTextView（这条与输入源无关）。
///
/// - Note: `-AppleLanguages` / `-AppleLocale` 只影响**文案本地化**，
///   不影响**键盘输入源**。两者是正交的，缺一不可。
/// - Note: `-AppleInputSourceOverride` 解决不了输入源问题——它只影响
///   TIS 输入源选择，不阻止候选栏弹出。正解是运行时用 TIS 切换
///   （`UITestInputSource.switchToEnglish`），不走启动参数。
class LumiUITestCase: XCTestCase {
    /// App 实例。子类直接使用，不要重复创建。
    var app: XCUIApplication!

    /// 切换输入源前的原始输入源 ID，tearDown 时据此还原。
    ///
    /// - Important: 输入源是**用户的全局状态**，不还原会改掉开发者的输入法
    ///   配置，比脏剪贴板更严重。详见 `UITestInputSource`。
    private var originalInputSourceID: String?

    /// 启动时是否成功切到了目标输入法。
    ///
    /// 中文拼音用例据此决定跳过：本机没装中文输入法时切不过去，
    /// 用例的失败点会落在「输入法没切过去」而不是被测行为上。
    private(set) var didSwitchInputSource = false

    /// UI 测试启动时的输入法策略。
    enum InputSourceStrategy {
        /// 切到英文 ASCII 布局（默认）。
        ///
        /// IME 组合态不出现，`typeText` 稳定地逐字落成字符。
        case englishASCII
        /// 切到中文拼音输入法。
        ///
        /// 合成按键会进入 IME 组合态（拼音缓冲区），用来覆盖真实的中文输入路径。
        case chinesePinyin
    }

    /// 本次启动使用的输入法策略。
    ///
    /// 存下来是为了让 ``applyInputSourceStrategy()`` 能在 App 起来之后**再切一次**。
    private var inputSourceStrategy: InputSourceStrategy = .englishASCII

    /// 以确定性 LLM 供应商 + 隔离存储启动 App。
    ///
    /// - Parameters:
    ///   - extraArguments: 额外的启动参数（场景专属夹具）。
    ///   - inputSource: 启动时切换到哪个输入法。默认英文 ASCII；中文输入法
    ///     用例需要显式传 `.chinesePinyin`，并在 App 起来后调用
    ///     ``applyInputSourceStrategy()`` 重新切换一次。
    func launchLumi(
        extraArguments: [String] = [],
        inputSource: InputSourceStrategy = .englishASCII
    ) {
        // - Important: 切换输入源放在 `launchLumi` 而**不是** `setUpWithError`：
        //   绝大多数子类覆写 `setUpWithError` 后不调用 `super`，基类钩子
        //   不会执行，挂在那里等于没挂。`launchLumi` 是所有用例的必经之路。
        inputSourceStrategy = inputSource
        switch inputSource {
        case .englishASCII:
            switchToEnglishInputSource()
        case .chinesePinyin:
            switchToChinesePinyinInputSource()
        }

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
        // 还要清掉**别的**同 bundle id 实例：见 `terminateOtherRunningInstances()`。
        terminateOtherRunningInstances()

        app.launchArguments += Self.commonLaunchArguments + extraArguments
        app.launch()
    }

    /// 把输入源切到英文（ASCII），并在 tearDown 时还原。
    ///
    /// 切换失败**不中断用例**：切不过去只是退回原有的输入法行为
    /// （可能丢尾部空格），不该让整批测试因此无法运行。
    private func switchToEnglishInputSource() {
        guard originalInputSourceID == nil else { return }
        originalInputSourceID = UITestInputSource.switchToEnglish()
        didSwitchInputSource = originalInputSourceID != nil
    }

    /// 把输入源切到中文拼音，并在 tearDown 时还原。
    ///
    /// 与英文路径相反：这里切不过去意味着**用例测不到目标行为**
    /// （本机没装中文输入法），因此用例应当据 `didSwitchInputSource` 跳过，
    /// 而不是继续跑出一个必然失败的断言。
    private func switchToChinesePinyinInputSource() {
        guard originalInputSourceID == nil else { return }
        originalInputSourceID = UITestInputSource.switchToChinesePinyin()
        didSwitchInputSource = originalInputSourceID != nil
    }

    /// 在 App 已经起来并激活之后，**再**应用一次输入法策略。
    ///
    /// - Important: 中文输入法用例必须在 App 激活后重新切换，否则测不到 IME。
    ///   macOS 的输入源属于**当前活动应用**：在 `launchLumi` 里（即 App 启动前）
    ///   切换，改的是当时前台应用（xcodebuild / 测试宿主）的输入源；随后新起的
    ///   Lumi 进程会拿回**它自己记住的**输入源。
    ///   症状很有迷惑性：合成按键被直接落成 ASCII 字母（拼音原样留在输入框里，
    ///   尾部空格也没被 IME 吃掉），看起来像「中文输入法坏了」，实际是切换时机不对。
    ///
    ///   调用方应先 `app.activate()`，再调本方法。
    func applyInputSourceStrategy() {
        switch inputSourceStrategy {
        case .englishASCII:
            switchToEnglishInputSource()
        case .chinesePinyin:
            // 还原后再切一次：`switchToChinesePinyinInputSource` 有
            // `originalInputSourceID == nil` 的守卫，直接调用不会生效。
            guard let originalID = originalInputSourceID else {
                switchToChinesePinyinInputSource()
                return
            }
            originalInputSourceID = originalID
            didSwitchInputSource = UITestInputSource.switchToChinesePinyin() != nil
        }
    }

    /// 还原输入源与剪贴板。
    ///
    /// 子类若覆写 `tearDownWithError`，通常会调 `super.tearDownWithError()`，
    /// 因此正常情况下会自动走到这里。子类也可显式调用它做提前还原。
    func restoreUserState() {
        if let originalInputSourceID {
            UITestInputSource.restore(originalInputSourceID)
            self.originalInputSourceID = nil
        }
    }

    override func tearDownWithError() throws {
        // 还原输入源放在这里而不是让每个子类显式调：
        // 所有子类都会调 `super.tearDownWithError()`，挂在基类才不会漏。
        // 不还原会改掉开发者的输入法配置——比脏剪贴板更严重。
        restoreUserState()
        try super.tearDownWithError()
    }

    /// 结束同 bundle id 的其它残留实例。
    ///
    /// - Important: `XCUIApplication().state` 对**新建**实例恒为 `.notRunning`——
    ///   它并不知道系统里已经有一个同 id 的 App 在跑。因此
    ///   `terminateAppAndWait()` 在启动阶段什么也做不了。
    ///
    ///   而 `app.launch()` 在发现同 id 实例已存在时**不会新起进程**，
    ///   只会去激活那个旧实例——一个缩在后台的残留进程就会让 launch 报
    ///   `Failed to activate application … (current state: Running Background)`。
    ///   错误信息指向「激活失败」，真实原因却是「上一次的进程还在」，
    ///   两者毫无关联。
    ///
    ///   Lumi 的退出尤其慢（要卸载 240+ 个本地包），所以这一步不是可有可无的保险。
    private func terminateOtherRunningInstances() {
        // Debug 构建的 bundle id（见 `LumiApp/Config/Lumi-Debug.xcconfig`）。
        //
        // - Important: 必须是 **Debug** 专属 id，不能按 App 名匹配：
        //   用户安装的正式版是 `com.coffic.lumi`，
        //   按名字匹配会误杀用户正在运行的 App。
        let bundleID = "com.coffic.lumi.debug"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }
        guard !others.isEmpty else { return }

        others.forEach { $0.terminate() }

        // 等它们真的退出；等不到就强制结束。
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            let alive = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0 != NSRunningApplication.current && !$0.isTerminated }
            if alive.isEmpty { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current && !$0.isTerminated }
            .forEach { kill($0.processIdentifier, SIGKILL) }
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
    /// - Important: Lumi 退出很慢（要卸载 240+ 个本地包），10s 往往不够。
    ///   旧实例没退干净时，`launch()` 会复用那个后台实例，
    ///   表现为 `Failed to activate application (current state: Running Background)`
    ///   ——错误信息指向「激活失败」，真实原因却是「上一次的进程还在」，
    ///   两者毫无关联，极易误判成产品缺陷。
    ///
    ///   因此这里等满 30s；仍未退出就升级为强制结束，
    ///   把「进程没退干净」这件事变成确定的事实，而不是留给下一个用例的随机失败。
    ///
    /// - Important: 必须调用它而不是裸 `terminate()`，
    ///   否则「上一个用例还在退出」会泄漏成「下一个用例偶发失败」——
    ///   这种失败点随机漂移，极难归因。
    func terminateAppAndWait(timeout: TimeInterval = 30) {
        guard app.state != .notRunning else { return }
        app.terminate()
        let stopped = NSPredicate(format: "state == %d", XCUIApplication.State.notRunning.rawValue)
        let expectation = XCTNSPredicateExpectation(predicate: stopped, object: app)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            // 进程赖着不走：强制结束，否则它会一直占着 bundle id，
            // 让下一个用例的 launch() 激活到旧实例上。
            app.terminate()
            let forced = NSPredicate(format: "state == %d", XCUIApplication.State.notRunning.rawValue)
            let forcedExpectation = XCTNSPredicateExpectation(predicate: forced, object: app)
            if XCTWaiter().wait(for: [forcedExpectation], timeout: 10) != .completed {
                XCTFail(
                    """
                    App 未在 \(Int(timeout))s 内退出（当前状态：\(app.state.rawValue)）。\
                    后续交互会失败在「无法激活应用」而非真实断言上，请勿据此判定产品缺陷。
                    """
                )
            }
        }
    }

    /// 等待主窗口就绪。
    func waitForMainWindow() {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30),
            "主窗口未就绪"
        )
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
    /// ## 为什么点按钮而不是按 Return
    ///
    /// 候选栏是系统模态层，`typeKey(.return)` 会被它用于「上屏」而**永远不会到达
    /// NSTextView**，于是回合永不启动。点击发送按钮不经过键盘事件链，不受影响。
    /// 按钮的 `disabled` 判定由空内容驱动，仍能覆盖「空内容不可发送」这一行为。
    ///
    /// 写入正文本身走 `typeText`（见该方法注释），不进剪贴板。
    ///
    /// - Returns: 是否成功写入并点下发送（失败时后续断言会给出更具体的原因）。
    @discardableResult
    func typeAndSend(_ text: String, editorIdentifier: String) -> Bool {
        let editor = element(identifier: editorIdentifier)
        guard editor.waitForExistence(timeout: 20) else { return false }
        typeText(text, into: editor)

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

    /// 逐字符把文本输入到控件（首选路径）。
    ///
    /// ## 为什么它现在是安全的
    ///
    /// 早期 `typeText` 会**丢掉最后一个空格**——合成按键进入了宿主中文拼音
    /// 输入法的组合态，空格被 IME 用于「上屏」而没进控件（实测三组对照见
    /// `UITestInputSource` 的类注释）。
    ///
    /// `launchLumi` 现在会在启动前把输入源切到英文 ASCII 布局，并在
    /// tearDown 还原。IME 组合态只在非拉丁布局下出现，切走后这条路径不复存在，
    /// `typeText` 恢复成真正的「模拟用户逐字打字」。
    ///
    /// 这比剪贴板更接近真实用户：用户往输入框里打字走的就是这条链路，
    /// 而 ⌘V 模拟的是「复制一段文字粘过来」，那是另一条产品功能。
    ///
    /// ## 与 `paste` 的取舍
    ///
    /// - `typeText`：模拟用户输入，不碰剪贴板（用户全局状态），首选。
    /// - `paste`：仅供**需要测真实粘贴行为**的用例使用。⌘V 依赖输入源正确
    ///   路由修饰键，但切到英文后同样稳定。
    ///
    /// 写入是否成功不在这里校验：AX 快照里长文本的 `value` 会被**截断显示**
    /// （例如 `value: 'UI Testing Send Button Probe'` 显示成
    /// `value: 'UI Testing Send Button Pr…'`），那是快照的显示缩写，
    /// 不是控件真实内容。用它做全等比对会对长文案一律误报。
    /// 真正的判据是调用方后续的断言（如 `typeAndSend` 等发送按钮变为可用）。
    func typeText(_ text: String, into element: XCUIElement) {
        element.click()
        element.typeText(text)
    }

    /// 通过剪贴板把文本写入控件。
    ///
    /// ## 何时才该用
    ///
    /// 仅当用例要验证**真实粘贴**这条产品功能时。其余场景一律用 `typeText`——
    /// 输入框对这些用例只是「有文本、按钮可用」的前置条件载体，
    /// 用 ⌘V 去搭前置条件，等于让一条无关路径承担失败的 blame。
    ///
    /// 剪贴板是用户的全局状态，用完立即还原（见 `UITestClipboard`）。
    func paste(_ text: String, into element: XCUIElement) {
        // 剪贴板是全机器共享的系统资源，用完必须还原，否则会覆盖用户自己
        // 复制的内容，并一直留到用户手动再复制一次为止。
        // 详见 `UITestClipboard` 的说明。
        UITestClipboard.preserving {
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
    ///   TIS 输入源选择，不阻止候选栏弹出，解决不了输入源问题。
    ///   正解是运行时用 TIS 切换（`UITestInputSource`），由 `launchLumi` 调用，
    ///   这样既能覆盖用户已启用的输入源，又能在 tearDown 还原。
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
