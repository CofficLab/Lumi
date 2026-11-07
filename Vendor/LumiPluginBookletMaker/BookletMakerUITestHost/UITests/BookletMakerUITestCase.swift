import XCTest

/// BookletMaker 插件 UI 测试基类。
///
/// 统一处理启动、macOS 窗口激活竞态与锚点查询，让各测试文件只关心被测行为。
///
/// 两条关键约定：
/// 1. **只用 `accessibilityIdentifier` 定位元素**，不用文案。标识随语言切换保持
///    稳定，文案则会被本地化改动打断。
/// 2. **断言状态而非存在性**。元素存在只说明渲染了，不代表功能可用；真正要
///    校验的是选中态、启用态、门控原因这些用户能感知的行为。
class BookletMakerUITestCase: XCTestCase {
    var app: XCUIApplication!

    /// 被测宿主 App 的 bundle id，用于等待其真正成为前台应用。
    /// 被测宿主 App 的 bundle id；等待前台、定位沙盒容器都要用。
    static let hostBundleID = "com.coffic.bookletmaker.testhost"

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchApp(language: "en", locale: "en_US")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    /// 以指定语言启动宿主 App。
    ///
    /// 语言通过 `-AppleLanguages` / `-AppleLocale` 注入而非依赖 CI 主机设置，
    /// 使本地化测试在任何机器上结果一致。
    func launchApp(language: String, locale: String) {
        app = XCUIApplication()
        // 打开插件的测试接缝。
        //
        // 合并队列靠它注入夹具；导出面板靠它把保存位置预选到宿主自己的临时
        // 目录。这一行曾经只写在合并队列的启动器里，基类的常规启动器漏了——
        // 于是导出测试在**关闭**接缝的情况下运行，宿主（测试宿主未开沙盒）
        // 把产物写进了用户的「文稿」目录。断言照样全绿，问题只在事后表现为
        // 「用户文件夹里多出一个 PDF」，极易被当成偶发残留忽略掉。
        //
        // 因此它必须留在基类：任何一个 UI 测试都用同一套装配，不要按需再设。
        app.launchEnvironment["BOOKLET_MAKER_UI_TESTING"] = "1"
        app.launchArguments += [
            "-AppleLanguages", "(\(language))", "-AppleLocale", locale,
            "-ApplePersistenceIgnoreState", "YES",
        ]
        app.launch()
        #if os(macOS)
        waitForForeground()
        waitForWorkspace()
        #endif
    }

    #if os(macOS)
    /// 等待被测 App 成为前台应用。
    ///
    /// `activate()` 是异步的：App 未到前台时，对窗口内控件的首次点击只会把
    /// 窗口激活而不送达控件（交互静默失败）。必须等到真正 frontmost。
    private func waitForForeground() {
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Self.hostBundleID {
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    /// 等待前台就绪且工作区装配完成。
    ///
    /// 供需要自定义启动参数（如注入测试夹具）的场景复用。
    func waitForForegroundAndWorkspace() {
        waitForForeground()
        waitForWorkspace()
    }

    /// 等待被测 App 成为前台应用；超时则明确失败。
    ///
    /// 与 `waitForForeground()` 的区别：这里把「等不到前台」当作失败抛出，
    /// 而不是静默继续。注入测试夹具会让启动变慢，随后的点击若在 App 尚未
    /// 到前台时发出，会得到「not foreground and does not allow background
    /// interaction」这类难以定位的报错——提前失败并给出诊断更省事。
    func waitForForegroundOrFail(
        timeout: TimeInterval = 40,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Self.hostBundleID {
            Thread.sleep(forTimeInterval: 0.2)
        }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.hostBundleID else {
            XCTFail(
                "被测 App 未在 \(Int(timeout))s 内成为前台。"
                    + "当前前台：\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "<none>")",
                file: file,
                line: line
            )
            return
        }
    }

    /// 等待插件工作区完成装配并激活。
    ///
    /// 以侧栏工具入口作为「装配完成」的信号：只有插件 `onBoot` 注册了
    /// ActivityBar 条目、且激活闭包跑完（Rail/工具栏就绪）后它才会出现。
    func waitForWorkspace() {
        let tool = element("overview.bookletTool")
        XCTAssertTrue(
            tool.waitForExistence(timeout: 30),
            "插件工作区未在超时内完成装配。\(app.debugDescription)"
        )
    }
    #endif

    // MARK: - Element Query

    /// 按 `accessibilityIdentifier` 查找元素（首选方式）。
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    /// 断言元素处于某状态，比较 `value` 与 `label` 两个属性。
    ///
    /// macOS AX 树里 StaticText 的文本走 `value`，Button 的走 `label`，
    /// 同一个 `.accessibilityValue` 修饰符落到不同控件上暴露的属性也不同，
    /// 因此两个属性都要检查。
    func hasValue(_ element: XCUIElement, _ expected: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@ OR label == %@", expected, expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// 读取元素承载的文本，`value` 优先、`label` 兜底。
    func text(of element: XCUIElement) -> String {
        if let value = element.value as? String, !value.isEmpty { return value }
        return element.label
    }

    /// 点击工具入口，并等待切换后的目标视图出现。
    ///
    /// 反复重试直到成功，因为两类瞬态都要靠重试化解：
    /// 1. 首击可能被 macOS 窗口激活竞态吞掉（只激活窗口不切换工具）；
    /// 2. App 尚未真正前台时，读取 `isHittable` 或 `click()` 本身就会抛
    ///    「not foreground」或「no longer valid after interruption
    ///    handling」——这是查询期异常而非返回 false，必须用 `try?` 兜住
    ///    才有重试机会。
    ///
    /// 注意不要在循环里调用 `app.activate()`：激活动作会打断当前首次响应者，
    /// 反而让已打开的系统面板被收起。
    func switchTool(
        _ identifier: String,
        expecting anchor: String,
        timeout: TimeInterval = 25,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let tool = element(identifier)
        let target = element(anchor)

        guard tool.waitForExistence(timeout: timeout) else {
            XCTFail(
                "工具入口 \(identifier) 缺失。\(app.debugDescription)",
                file: file, line: line
            )
            return
        }

        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?
        while Date() < deadline {
            do {
                try tool.click()
                if target.waitForExistence(timeout: 6) { return }
            } catch {
                // 元素在点击瞬间失效（焦点切换等）：记下来，稍后重试。
                lastError = error
            }
            Thread.sleep(forTimeInterval: 1.0)
        }

        let reason = lastError.map { "最后一次失败：\($0.localizedDescription)" } ?? ""
        XCTFail(
            "切换到 \(identifier) 后未出现 \(anchor)。\(reason)\(app.debugDescription)",
            file: file, line: line
        )
    }

    /// 在模态面板（系统保存/选择面板）打开期间点击底层界面元素。
    ///
    /// `runModal()` 打开的系统面板会让 XCUITest 的事件路由停在
    /// "Handler claimed to have handled ... but it's still interrupting"：
    /// 它认为点击已被面板消费，却仍把事件判给下层控件。这类面板没有可靠的
    /// API 去解除，只能等它自己关闭。因此这里轮询等待面板消失，再交给调用方。
    ///
    /// - Returns: 是否在超时前成功等到面板关闭。
    @discardableResult
    func waitForModalPanelToClose(timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.dialogs.count == 0 { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return app.dialogs.count == 0
    }

    /// 点击保存后可能出现的「替换现有文件」确认框。
    ///
    /// `NSSavePanel` 在目标文件已存在时，会在面板之上再叠一个确认 sheet，
    /// 提供 Replace / Skip 两个按钮（AX 上分别为 `action-button-1` /
    /// `action-button-2`）。它出现在**面板内部**而非独立窗口，且没有可读
    /// 标题，因此只能按 `sheet` 的存在性与按钮 identifier 识别。
    ///
    /// 这里等到该 sheet 出现后点第一个按钮（Replace），并等面板真正关闭。
    /// 没有已存在文件时该 sheet 不会出现，属于正常路径。
    func confirmReplaceIfPresent(timeout: TimeInterval = 10) {
        let sheet = app.sheets.firstMatch
        guard sheet.waitForExistence(timeout: timeout) else { return }

        // 第一个按钮是「替换」，第二个是「跳过」。
        let replace = sheet.buttons["action-button-1"]
        guard replace.waitForExistence(timeout: 5) else { return }
        replace.click()
    }

    /// 点击元素并等待它进入指定状态，失败则重试。
    ///
    /// 用于「点击后状态才变化」的控件：切分点、纸张选项等。首击可能被窗口
    /// 激活竞态吞掉，重试即可；不重试则会把偶发失败误判成缺陷。
    ///
    /// 每次尝试都重新查询元素：系统面板关闭后，旧的 `XCUIElement` 会因为
    /// 底层快照过期而读到陈旧的值——曾出现「实际值就是 selected 却仍报失败」。
    func clickAndWaitForValue(
        _ identifier: String,
        _ expected: String,
        timeout: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        var clicked = false
        var lastSeen: String?

        while Date() < deadline {
            let current = element(identifier)
            if current.exists {
                let value = (current.value as? String) ?? current.label
                lastSeen = value
                if value == expected { return }

                if !clicked {
                    do {
                        try current.click()
                        clicked = true
                    } catch {
                        clicked = false
                    }
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTFail(
            "点击 \(identifier) 后未进入状态 \(expected)，最后读到 \(lastSeen ?? "<无值>")。\(app.debugDescription)",
            file: file, line: line
        )
    }

    /// 断言工具入口处于选中态。
    func assertSelected(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let tool = element(identifier)
        XCTAssertTrue(
            hasValue(tool, "selected"),
            "工具 \(identifier) 应为选中态。\(app.debugDescription)",
            file: file,
            line: line
        )
    }

    /// 断言匹配文案的元素存在，用于验证本地化结果（唯一允许用文案的场景）。
    func localizedText(_ value: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", value, value))
            .firstMatch
    }
}

extension XCUIElement {
    /// 按平台选择点击方式：iOS 用 tap，macOS 用 click。
    ///
    /// 放在扩展里而不是测试基类上：它是元素的操作，不是测试基类的能力。
    func tapOrClick() {
        #if os(iOS)
        tap()
        #else
        click()
        #endif
    }
}
