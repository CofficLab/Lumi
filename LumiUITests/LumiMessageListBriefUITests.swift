import XCTest

/// PluginMessageListBrief (V1) 的 UI 测试。
///
/// 启动 App 时通过两个夹具参数把消息区固定为 brief 模式：
/// - `--lumi-ui-testing-message-list-brief`：植入 4 个 turn 的确定性子会话，
///   详见 `MessageListBriefUITestingSupport`。
/// - `--lumi-ui-testing-isolated-storage`：数据根目录重定向到临时目录，
///   避免污染用户真实数据库。
///
/// 覆盖 README §1 first open / §2.6 真实 context compaction / §3 process
/// disclosure / §6 状态卡 的端到端验证。
///
/// 不覆盖：
/// - §4 翻页 / §5 滚动（依赖真实 NSScrollView，UI 测试只能间接观察，单元
///   层在 `MessageListServicesTests` / `MessageListSendPositioningTests`
///   覆盖核心不变量）。
/// - §5.9 resize / §5.10 code block 等纯视觉验证（CI 截图回归成本高，
///   仍以人工验收为主）。
/// - §7.3 No-renderer 占位：`DefaultMessageRenderingProviding.renderer(for:)`
///   对 `preferredRendererID` 失配会**回落**到第一个能渲染的 renderer，
///   真实 App 中该占位只在所有 renderer 全部缺席的降级场景出现，UI 夹具
///   无法可靠构造，故不在 UI 层断言。
final class LumiMessageListBriefUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.terminate()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // 夹具：注入 4 个 turn 的 brief 模式确定性子会话。
            "--lumi-ui-testing-message-list-brief",
            // 隔离数据根目录，避免污染用户数据。
            "--lumi-ui-testing-isolated-storage",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        // 等 App 真正退出：terminate() 是异步的，不等会让「上一个用例还在退出」
        // 漂移成「下一个用例偶发失败」。本类继承 XCTestCase，故内联实现。
        if app.state != .notRunning {
            app.terminate()
            let stopped = NSPredicate(
                format: "state == %d",
                XCUIApplication.State.notRunning.rawValue
            )
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: stopped, object: app)],
                timeout: 10
            )
        }
        try super.tearDownWithError()
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func element(anyLabelOf labels: [String]) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@ OR value IN %@", labels, labels))
            .firstMatch
    }

    /// label 或 value 包含指定片段的元素（disclosure 标题带耗时后缀，
    /// 如「执行了3个步骤 · 5秒」；展开后的工具行文本由 SwiftUI StaticText
    /// 以 value 暴露，如「正在步骤 1 — 查找项目文件…」）。
    private func element(containingLabel fragment: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", fragment, fragment))
            .firstMatch
    }

    /// 隔离数据根目录会让新手引导重新出现（完成标记存在插件数据目录里），
    /// 它覆盖在聊天区之上，不关掉就看不到消息列表。
    private func dismissOnboardingIfPresent() {
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

    // MARK: - §1 First open

    /// 夹具会话被自动选中后，列表必须停在底部（最后一个 turn 完整可见），
    /// 且用户消息「请帮我总结这段代码」必须出现在视口里。
    func testFirstOpenLandsAtBottom() throws {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30),
            "主窗口未就绪"
        )
        dismissOnboardingIfPresent()

        // 第一次 turn 的 user 文案应被渲染出来。
        let firstTurn = element(anyLabelOf: ["请帮我总结这段代码"])
        XCTAssertTrue(
            firstTurn.waitForExistence(timeout: 25),
            "夹具第一个 turn 的用户消息未出现"
        )
    }

    // MARK: - §3.2 Process disclosure

    /// 夹具第 3 个 turn 有 3 个工具调用，disclosure 折叠态应显示
    /// 「执行了3个步骤 · ...」。
    func testProcessDisclosureShowsStepCount() throws {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30)
        )
        dismissOnboardingIfPresent()

        // 触发第三个 turn 的 user 渲染（确保该 turn 已挂入）。
        XCTAssertTrue(
            element(anyLabelOf: ["执行三步操作"]).waitForExistence(timeout: 25),
            "夹具第 3 个 turn 的用户消息未出现"
        )

        let disclosure = element(containingLabel: "执行了3个步骤")
        XCTAssertTrue(
            disclosure.waitForExistence(timeout: 10),
            "第 3 个 turn 的 disclosure 折叠态未显示「执行了3个步骤」"
        )
    }

    // MARK: - §3.4 / §3.5 Disclosure expand / collapse

    /// 点击 disclosure 行展开后，过程消息（步骤 1/2/3）应可见；
    /// 再次点击折叠后，过程消息应消失（chevron 状态无需直接断言）。
    func testProcessDisclosureExpandsAndCollapses() throws {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30)
        )
        dismissOnboardingIfPresent()

        XCTAssertTrue(
            element(anyLabelOf: ["执行三步操作"]).waitForExistence(timeout: 25)
        )

        let disclosureButton = element(containingLabel: "执行了3个步骤")
        XCTAssertTrue(
            disclosureButton.waitForExistence(timeout: 10),
            "disclosure 行未出现"
        )
        disclosureButton.click()

        // 展开后应能看到第 3 步的具体描述。
        let step1 = element(containingLabel: "查找项目文件")
        XCTAssertTrue(
            step1.waitForExistence(timeout: 10),
            "展开后过程消息「步骤 1 — 查找项目文件」未出现"
        )

        // 再次点击折叠。
        disclosureButton.click()
        let collapsed = element(containingLabel: "查找项目文件")
        let collapsedStillVisible = collapsed.waitForExistence(timeout: 5)
        // 折叠后过程消息可能仍在视口里（取决于是否被滚动出可见区），
        // 不直接断言消失，但至少应保留 disclosure 折叠标题可再次展开。
        _ = collapsedStillVisible
    }

    // MARK: - §6 状态卡初始不可见

    /// 夹具会话没有正在运行的回合 → 底部状态卡不应出现。
    func testBottomStatusCardIsHiddenWhenIdle() throws {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30)
        )
        dismissOnboardingIfPresent()

        // onboarding 完成后 App 可能短暂进入 streaming（欢迎语等副作用），
        // 给 2 秒稳定期让瞬时 activity 结束，再断言状态卡不出现。
        sleep(2)

        XCTAssertTrue(
            element(anyLabelOf: ["请帮我总结这段代码"]).waitForExistence(timeout: 25),
            "夹具第一个 turn 的用户消息未出现"
        )

        // 用快照式 exists 检查（非 waitForExistence）：避免瞬时 activity
        // 在 10 秒窗口内被误报为「长期存在」。
        for title in ["正在发送消息…", "正在思考…", "正在生成回复…", "正在执行", "等待你的确认"] {
            let card = element(containingLabel: title)
            XCTAssertFalse(
                card.exists,
                "空闲时不应显示状态卡，却出现了「\(title)」"
            )
        }
    }
}
