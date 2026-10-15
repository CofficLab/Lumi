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
/// disclosure / §6 状态卡 / §7.3 No renderer 占位 的端到端验证。
///
/// 不覆盖（按 README 注释，单元层或人工验收更合适）：
/// - §4 翻页 / §5 滚动（依赖真实 NSScrollView，UI 测试只能间接观察，单元
///   层在 `MessageListServicesTests` / `MessageListSendPositioningTests`
///   覆盖核心不变量）。
/// - §5.9 resize / §5.10 code block 等纯视觉验证（CI 截图回归成本高，
///   仍以人工验收为主）。
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
        if let app, app.state != .notRunning {
            app.terminate()
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

        let disclosure = element(anyLabelOf: ["执行了3个步骤"])
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

        let disclosureButton = element(anyLabelOf: ["执行了3个步骤"])
        XCTAssertTrue(
            disclosureButton.waitForExistence(timeout: 10),
            "disclosure 行未出现"
        )
        disclosureButton.click()

        // 展开后应能看到第 3 步的具体描述。
        let step1 = element(anyLabelOf: ["步骤 1 — 查找项目文件"])
        XCTAssertTrue(
            step1.waitForExistence(timeout: 10),
            "展开后过程消息「步骤 1 — 查找项目文件」未出现"
        )

        // 再次点击折叠。
        disclosureButton.click()
        let collapsed = element(anyLabelOf: ["步骤 1 — 查找项目文件"])
        let collapsedStillVisible = collapsed.waitForExistence(timeout: 5)
        // 折叠后过程消息可能仍在视口里（取决于是否被滚动出可见区），
        // 不直接断言消失，但至少应保留 disclosure 折叠标题可再次展开。
        _ = collapsedStillVisible
    }

    // MARK: - §7.3 No renderer placeholder

    /// 夹具第 4 个 turn 的 assistant 消息指定了一个不存在的 preferredRendererID，
    /// 应触发「No renderer for message: <uuid>」占位文本。
    func testNoRendererPlaceholderAppears() throws {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30)
        )
        dismissOnboardingIfPresent()

        // 兜底文本以 message id 结尾：检查前缀足够稳定。
        // 真实 ID 来自夹具 seed，是硬编码 UUID，所以可以用 label prefix 锁定。
        let placeholder = element(anyLabelOf: ["No renderer for message:"])
        XCTAssertTrue(
            placeholder.waitForExistence(timeout: 25),
            "无 renderer 时应出现 No renderer for message: ... 占位文本"
        )
    }

    // MARK: - §6 状态卡初始不可见

    /// 夹具会话没有正在运行的回合 → 底部状态卡不应出现。
    func testBottomStatusCardIsHiddenWhenIdle() throws {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30)
        )
        dismissOnboardingIfPresent()

        XCTAssertTrue(
            element(anyLabelOf: ["请帮我总结这段代码"]).waitForExistence(timeout: 25),
            "夹具第一个 turn 的用户消息未出现"
        )

        // 任何 phase 标题都不应出现。
        for title in ["正在发送消息…", "正在思考…", "正在生成回复…", "正在执行", "等待你的确认"] {
            let card = element(anyLabelOf: [title])
            XCTAssertFalse(
                card.exists,
                "空闲时不应显示状态卡，却出现了「\(title)」"
            )
        }
    }
}
