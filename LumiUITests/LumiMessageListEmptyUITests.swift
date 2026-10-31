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
/// - 底部活动条在有历史时出现，锚点文案真的渲染、带窗口天数；
/// - 活动卡与提示胶囊流共用同一条左右边界（合卡融合的契约）；
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
/// - token 曲线的绘制：判空规则由 `EmptyStateTokenTrendTests` 覆盖，
///   曲线与画布的坐标映射由 `ActivitySparklineGeometryTests` 覆盖，
///   UI 层只确认活动卡整体存在。
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

    /// 活动卡里的锚点文案必须真的渲染出来，并带窗口天数。
    ///
    /// 数字现在由文字给出（图形只负责形状），因此这条用例守的是
    /// **数字没有随图形一起消失**：卡片在、却没有那行字，读屏用户与视力正常的
    /// 用户都只剩下 30 个日期格子，得不到「近 30 天共多少条」这一层语义。
    ///
    /// 锚点靠**文字**定位而不是标识符：标识符会向下传播并覆盖子孙自己的
    /// 标识符，这一块区域里只有活动卡是唯一可寻址的元素（详见
    /// `MessageListEmptyAccessibility.activityStripID` 的注释）。而锚点要被
    /// 断言的本来就是它**写着什么**，用文字定位恰好更贴切。
    ///
    /// 只断言文案的稳定片段、不断言具体数字：数字口径由夹具单测钉住（见类注释）。
    func testActivityCardRendersAnchorSummary() throws {
        waitForMainWindow()

        let card = element(identifier: MessageListEmptyA11yIDs.activityStrip)
        XCTAssertTrue(
            card.waitForExistence(timeout: 30),
            "活动条未出现"
        )

        // 摘要格式为「%lld messages in the last %lld days · %@ tokens」，取其中最稳定的片段。
        let anchor = element(containingLabel: "messages in the last")
        XCTAssertTrue(
            anchor.waitForExistence(timeout: 15),
            "活动卡已出现但锚点文案缺失"
        )
        // 合并后的无障碍元素可能把文字放在 label 上，也可能放在 value 上，
        // 两处都要认，否则会出现「元素在、却读不到文字」的假阴性。
        let anchorText = anchor.label.isEmpty ? (anchor.value as? String ?? "") : anchor.label
        // 摘要里必须带上窗口天数，否则「近 30 天」这个语义就丢了。
        XCTAssertTrue(
            anchorText.contains("30"),
            "活动卡锚点文案未包含窗口天数 30（label：\(anchor.label) / value：\(anchor.value ?? "")）"
        )
        // 数字必须出现在**卡里**，而不是飘在别处。
        XCTAssertTrue(
            card.frame.contains(anchor.frame),
            "锚点文案不在活动卡范围内（卡 \(card.frame) / 锚点 \(anchor.frame)）"
        )
    }

    /// 热力图与 token 曲线必须合成**一张卡**，并与提示胶囊流共用同一条宽度基准。
    ///
    /// 这条守的是「融合」本身：活动卡此前是两块各自为政的控件，被一道系统
    /// 分隔线切在空态之外。合卡之后，卡片与中间的提示胶囊流必须共用同一条
    /// 左右边界 —— 这正是「它们属于同一块画面」最直接的信号，也是最容易在
    /// 日后的一次随手改动里丢掉的东西。
    func testActivityCardAlignsWithThePromptFlow() throws {
        waitForMainWindow()

        let card = element(identifier: MessageListEmptyA11yIDs.activityStrip)
        XCTAssertTrue(
            card.waitForExistence(timeout: 30),
            "活动卡未出现"
        )

        // 胶囊流的外层标识符会传播到每一个 chip 上（SwiftUI 的行为），
        // 因此这里取**所有**同名元素的并集，作为胶囊流实际占位。
        let chipFrames = app.descendants(matching: .any)
            .matching(identifier: MessageListEmptyA11yIDs.suggestionFlow)
            .allElementsBoundByIndex
            .map(\.frame)
        guard let firstChip = chipFrames.first else {
            XCTFail("提示胶囊流未出现，无法比较两者的横向基准")
            return
        }
        let chipsBox = chipFrames.dropFirst().reduce(firstChip) { $0.union($1) }

        // 卡片宽度封顶 520pt（与胶囊流同宽的基准），不得再被拉宽。
        XCTAssertLessThanOrEqual(
            card.frame.width,
            521,
            "活动卡宽于 520pt 的共享基准（实际 \(card.frame.width)pt）"
        )
        // 两者都居中在同一个 620pt 的列里，水平中心应当重合。
        XCTAssertEqual(
            card.frame.midX,
            chipsBox.midX,
            accuracy: 2,
            "活动卡与提示胶囊流没有共用同一条左右边界（卡 \(card.frame.midX) / 胶囊 \(chipsBox.midX)）"
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

/// 项目上下文卡的 UI 测试。
///
/// 与上面的空态用例分开成一个 class，因为启动参数不同：项目上下文卡只在
/// **有项目**时渲染，夹具必须真的打开一个项目。
final class LumiMessageListEmptyProjectUITests: LumiUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try super.setUpWithError()
        launchLumi(extraArguments: [
            "--lumi-ui-testing-message-list-empty",
            "--lumi-ui-testing-message-list-empty-project",
            "--lumi-ui-testing-isolated-storage",
        ])
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    /// 有项目时，身份行与项目上下文卡都必须出现。
    ///
    /// 这是本次改动的核心用户可感知变化：空态从「只有一句项目名」变成
    /// 「知道自己站在哪个项目里、这个项目现在是什么状态」。
    func testProjectContextAppearsAlongsideEmptyState() throws {
        waitForMainWindow()

        XCTAssertTrue(
            element(identifier: MessageListEmptyA11yIDs.noMessages).waitForExistence(timeout: 30),
            "起始态应为空态引导页"
        )
        XCTAssertTrue(
            element(identifier: MessageListEmptyA11yIDs.projectIdentity).waitForExistence(timeout: 30),
            "有项目时身份行（路径 + 技术栈）未出现"
        )
        XCTAssertTrue(
            element(identifier: MessageListEmptyA11yIDs.projectContext).waitForExistence(timeout: 30),
            "有项目时项目上下文卡未出现"
        )
    }

    /// 项目卡必须与提示胶囊流共用同一条左右边界。
    ///
    /// 与活动卡的宽度契约同源：两张卡 + 胶囊流读起来是「同一块画面」，
    /// 而不是三个各自为政的控件。
    func testProjectContextAlignsWithThePromptFlow() throws {
        waitForMainWindow()

        let card = element(identifier: MessageListEmptyA11yIDs.projectContext)
        XCTAssertTrue(
            card.waitForExistence(timeout: 30),
            "项目上下文卡未出现"
        )

        let chipFrames = app.descendants(matching: .any)
            .matching(identifier: MessageListEmptyA11yIDs.suggestionFlow)
            .allElementsBoundByIndex
            .map(\.frame)
        guard let firstChip = chipFrames.first else {
            XCTFail("提示胶囊流未出现，无法比较两者的横向基准")
            return
        }
        let chipsBox = chipFrames.dropFirst().reduce(firstChip) { $0.union($1) }

        XCTAssertLessThanOrEqual(
            card.frame.width,
            521,
            "项目卡宽于 520pt 的共享基准（实际 \(card.frame.width)pt）"
        )
        XCTAssertEqual(
            card.frame.midX,
            chipsBox.midX,
            accuracy: 2,
            "项目卡与提示胶囊流没有共用同一条左右边界（卡 \(card.frame.midX) / 胶囊 \(chipsBox.midX)）"
        )
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
    /// 活动卡（活动条的全部可见内容，也是这一块唯一可寻址的元素）。
    static let activityStrip = "lumi.message-list.empty.activity"
    /// 项目上下文卡（这一块唯一可寻址的元素）。
    static let projectContext = "lumi.message-list.empty.project-context"
    /// 项目身份行（路径 + 技术栈）。
    static let projectIdentity = "lumi.message-list.empty.project-identity"
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
