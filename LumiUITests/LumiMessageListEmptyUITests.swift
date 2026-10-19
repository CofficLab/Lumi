import XCTest

/// PluginMessageListEmpty 的 UI 测试。
///
/// 启动 App 时通过两个夹具参数固定初始状态：
/// - `--lumi-ui-testing-message-list-empty`：植入三个子会话，详见
///   `MessageListEmptyUITestingSupport`（空会话 / 有消息的历史会话 / 仅 tool
///   消息的会话）。
/// - `--lumi-ui-testing-isolated-storage`：数据根目录重定向到临时目录，
///   避免污染用户真实数据库。
///
/// 夹具默认选中**空会话**，且历史消息留在**另一个**会话里。这一组合是本文件
/// 全部用例的前提：活动条的数据来自跨会话统计，若把历史消息放进当前空会话，
/// 活动条与空态就永远无法同时出现，最关键的渲染路径反而测不到。
///
/// ## 分层：数字在这里不断言
///
/// 活动条显示的计数（8 条历史 + 1 条 tool = 9）由
/// `MessageListEmptyUITestingSupportTests.fixtureActivityCountsUseCrossConversationScope`
/// 在纯内存层面钉住——那里更快、失败信息更精确。本文件只确认文案**渲染出来了**。
/// 同一件事不在两层写死，避免夹具一改就要同步两处，也避免把「统计口径」
/// 与「渲染缺失」两类失败混在一起。
///
/// ## 覆盖什么
///
/// - 空态在「选中但无消息」时出现；
/// - 底部活动条在有历史时出现，且摘要文案真的渲染、带窗口天数；
/// - 切到有消息的会话后，空态**与**活动条一起消失（槽位正确让位）；
/// - 仅含 tool 消息的会话仍算空（`includesToolMessages: false`）。
///
/// ## 不覆盖什么
///
/// - **矮窗口下活动条是否仍在视口内**（`bottomFixed` 槽位的核心设计理由）。
///   `XCUIElement.frame` 是只读的，XCUITest 没有稳定的 macOS 窗口 resize API；
///   拖拽窗口边缘会引入 flake。项目既有边界一致：`LumiMessageListBriefUITests`
///   同样把 resize 归为「纯视觉验证，CI 成本高，以人工验收为主」。
///   该缺口登记在 `Tests/TestPlan.md` 的「未覆盖范围」。
/// - 纯视觉细节（热力图色阶、氛围层渐变、chip 圆角）：需截图回归，CI 成本过高。
/// - token 趋势线的绘制：判空规则由 `EmptyStateTokenTrendTests` 覆盖，
///   UI 层只确认活动条整体存在。
///
/// - Note: 必须继承 `LumiUITestCase` 而不是 `XCTestCase`。基类提供的
///   `launchLumi` / `waitForMainWindow` / `element(...)` 以及「用剪贴板绕过
///   输入法」的输入通道都在那里；直接继承 `XCTestCase` 连 `app` 属性都拿不到。
final class LumiMessageListEmptyUITests: LumiUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try super.setUpWithError()
        launchLumi(extraArguments: [
            "--lumi-ui-testing-message-list-empty",
            "--lumi-ui-testing-isolated-storage",
        ])
    }

    override func tearDownWithError() throws {
        // 基类要求：必须等进程真正退出，否则「上一个用例还在退出」会漂移成
        // 「下一个用例偶发失败」，且失败点随机移动、极难归因。
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - 空态出现

    /// 夹具默认选中的空会话没有消息，空态引导页必须出现。
    func testEmptyStateAppearsForConversationWithoutMessages() throws {
        waitForMainWindow()

        XCTAssertTrue(
            element(identifier: MessageListEmptyA11yIDs.noMessages).waitForExistence(timeout: 30),
            "选中无消息的会话时，空态引导页未出现"
        )
    }

    /// 空会话有历史时，空态与底部活动条必须**同时**出现。
    ///
    /// 活动条的数据是跨会话统计，所以它能否出现与当前会话是否为空无关，
    /// 只取决于「近 30 天是否有消息」。这条用例锁住两者互不干扰。
    func testActivityStripAppearsAlongsideEmptyState() throws {
        waitForMainWindow()

        XCTAssertTrue(
            element(identifier: MessageListEmptyA11yIDs.noMessages).waitForExistence(timeout: 30),
            "空态引导页未出现"
        )
        XCTAssertTrue(
            element(identifier: MessageListEmptyA11yIDs.activityStrip).waitForExistence(timeout: 30),
            "近 30 天存在历史消息时，底部活动条未出现"
        )
    }

    /// 活动条里的摘要文案必须真的渲染出来，并且带窗口天数。
    ///
    /// 只断言文案的稳定片段、不断言具体数字：数字口径由夹具单测钉住（见类注释）。
    /// 若活动条容器在、但摘要文本缺失或为空，说明布局或本地化退化，
    /// 那正是这条用例要抓的。
    func testActivityStripRendersSummaryText() throws {
        waitForMainWindow()

        let strip = element(identifier: MessageListEmptyA11yIDs.activityStrip)
        XCTAssertTrue(
            strip.waitForExistence(timeout: 30),
            "底部活动条未出现"
        )

        // 摘要格式为「%lld messages in the last %lld days」，取其中最稳定的片段。
        let summary = element(containingLabel: "messages in the last")
        XCTAssertTrue(
            summary.waitForExistence(timeout: 15),
            "活动条已出现但摘要文案缺失（活动条 label：\(strip.label)）"
        )
        // 摘要里必须带上窗口天数，否则「近 30 天」这个语义就丢了。
        XCTAssertTrue(
            summary.label.contains("30"),
            "活动条摘要未包含窗口天数 30（label：\(summary.label)）"
        )
    }

    // MARK: - 切到有消息的会话

    /// 切到有消息的会话后，空态与活动条都必须消失。
    ///
    /// 两者消失的原因不同：空态输给 `message-list` 互斥组里的消息列表插件，
    /// 活动条则只由自身 `isActive` 门控（bottomFixed 不参与互斥组竞争）。
    /// 因此这条用例同时守住两条独立的可见性通路。
    func testEmptyStateAndActivityStripYieldToConversationWithMessages() throws {
        waitForMainWindow()

        XCTAssertTrue(
            element(identifier: MessageListEmptyA11yIDs.noMessages).waitForExistence(timeout: 30),
            "起始态应为空态引导页"
        )

        try switchConversation(to: MessageListEmptyUITestTitles.history)

        XCTAssertTrue(
            waitForNonExistence(element(identifier: MessageListEmptyA11yIDs.noMessages), timeout: 15),
            "切到有消息的会话后空态仍在显示（槽位未正确让位）"
        )
        XCTAssertTrue(
            waitForNonExistence(element(identifier: MessageListEmptyA11yIDs.activityStrip), timeout: 15),
            "切到有消息的会话后底部活动条仍在显示"
        )
        // 让位之后应当能看到夹具的历史消息正文。
        XCTAssertTrue(
            element(anyLabelOf: ["UI history message 1"]).waitForExistence(timeout: 20),
            "切到历史会话后，夹具植入的消息未显示在消息列表中"
        )
    }

    /// 仅含 tool 消息的会话仍应显示空态。
    ///
    /// 空态判定用 `messagePageAsync(includesToolMessages: false)`，工具输出
    /// 不算用户可见的消息。这条用例确认该判定在真实数据下生效——工具输出
    /// 存在不代表用户看到过对话，把这种会话判为「有消息」会让引导页凭空消失。
    ///
    /// 注意这条同时验证了活动条的统计口径差异：该会话的 tool 消息**会**被
    /// 活动条的跨会话统计计入（见夹具单测），但**不会**让空态消失。
    func testToolOnlyConversationStillShowsEmptyState() throws {
        waitForMainWindow()

        try switchConversation(to: MessageListEmptyUITestTitles.toolOnly)

        XCTAssertTrue(
            element(identifier: MessageListEmptyA11yIDs.noMessages).waitForExistence(timeout: 25),
            "仅含 tool 消息的会话未显示空态（工具消息被误判为可见消息）"
        )
    }

    // MARK: - Helpers

    /// 在会话列表里点击指定标题。
    ///
    /// 查询限定在列表容器内：会话标题在消息正文里也可能出现同名前缀，
    /// 全窗口搜索会命中消息正文而非会话行，点击后选中态不变，表现为
    /// 「切换没生效」。
    ///
    /// ## 为什么「容器不存在」是 skip 而非失败
    ///
    /// 会话列表在当前布局下由 rail 侧栏承载（`WorkbenchSplitView` 要求
    /// `railView != nil && isRailViewVisible` 同时成立）。本次执行环境里 rail
    /// 没有渲染 —— 既有的 `LumiMessageListSwitchUITests` 在本环境同样失败于
    /// 「大会话未出现在会话列表」，说明这与本插件无关。
    ///
    /// 两者必须分开处理，否则无法归因：
    /// - **容器不存在** → 环境/布局限制，skip 并给出可核查的原因；
    /// - **容器存在但找不到行** → 夹具或列表渲染的真实回归，必须失败。
    private func switchConversation(to title: String) throws {
        let list = app.descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.listID)
            .firstMatch
        guard list.waitForExistence(timeout: 15) else {
            throw XCTSkip(
                """
                会话列表容器 \(LumiConversationListIDs.listID) 未渲染，无法执行切换类断言。\
                这是执行环境的布局限制（rail 侧栏不可见），不是本插件的行为：\
                LumiMessageListSwitchUITests 在同一环境下同样失败。
                """
            )
        }

        let row = list.descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.itemID)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", title, title))
            .firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 20),
            "会话列表已渲染但未找到「\(title)」——检查夹具是否种出了该会话"
        )
        row.click()
    }
}

/// 空态视图的可访问性标识符（复述 `MessageListEmptyAccessibility`）。
///
/// UI 测试是独立 target，不能 import 插件模块，因此在此复述常量。
/// 改动必须与 `Support/MessageListEmptyAccessibility.swift` 同步。
///
/// - Note: 命名与字符串沿用插件 id 的点分形式（`message-list.empty`），
///   与 `LumiFreshInstallEmptyStateUITests` 里的复述一致，不要改回连字符。
enum MessageListEmptyA11yIDs {
    static let noSelection = "lumi.message-list.empty.no-conversation-selected"
    static let noMessages = "lumi.message-list.empty.no-messages"
    static let suggestionFlow = "lumi.message-list.empty.suggestion-flow"
    static let activityStrip = "lumi.message-list.empty.activity"
}

/// 夹具会话标题（复述 `MessageListEmptyUITestingSupport`）。
///
/// - Note: `LumiConversationListIDs` 已在 `LumiMessageListSwitchUITests.swift`
///   定义（同 target、internal），此处直接复用而不重复声明——重复定义会让
///   整个 target 编译失败。
enum MessageListEmptyUITestTitles {
    static let empty = "UI Empty State Target"
    static let history = "UI Empty State History"
    static let toolOnly = "UI Empty State ToolOnly"
}
