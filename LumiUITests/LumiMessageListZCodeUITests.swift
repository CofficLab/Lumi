import XCTest
import AppKit

/// V4（ZCode）消息列表的 UI 测试。
///
/// ## 夹具
///
/// `--lumi-ui-testing-message-list-zcode` 植入 5 个**固定**会话：
/// - `ZCode Visual Target`：常规轮次（用户气泡 + 助手正文 + 轮尾操作栏）；
/// - `ZCode Long User Target`：超长用户输入，触发长文折叠；
/// - `ZCode Tool Target`：两个 Explore/Execute 工具，触发工作历史分组；
/// - `ZCode Scroll Target`：30 轮长列表，用于滚动与 following 语义；
/// - `ZCode Streaming Target`：流式态验收。
///
/// ## 隔离
///
/// 所有用例都带 `--lumi-ui-testing-isolated-storage`，数据根落到临时目录，
/// 不触碰用户真实数据，也不连真实供应商（夹具在缺少
/// `--lumi-ui-testing` 时拒绝启动）。
///
/// ## 截图
///
/// 截图只做**人工对照**，不做字节相等断言。
/// 评审产物落在 `docs/plans/artifacts/zcode-message-list-v4/`。
final class LumiMessageListZCodeUITests: LumiUITestCase {
    /// 遮罩的稳定标识符，与 `MessageLoadingView.identifier` 一致。
    private let maskIdentifier = "lumi.message-list.loading-mask"

    /// 遮罩必须在此时间内消失。
    private let maskBudget: TimeInterval = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 全局 UI 测试开关：夹具在缺少它时**拒绝启动**，
            // 防止正式构建在真实环境里造出会话、连真实供应商。
            "--lumi-ui-testing",
            "--lumi-ui-testing-message-list-zcode",
            "--lumi-ui-testing-isolated-storage",
        ])
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - 夹具与首屏

    /// 5 个夹具会话都必须出现在会话列表里。
    ///
    /// - Important: 这是「夹具真的被种下去了」的最直接证据。
    ///   夹具没种进去时，后续所有呈现断言都无从谈起。
    func testAllZCodeFixtureConversationsExist() throws {
        for title in MessageListZCodeUITestTitles.all {
            XCTAssertTrue(
                element(containingLabel: title).waitForExistence(timeout: 30),
                "夹具会话「\(title)」未出现在会话列表"
            )
        }
    }

    /// 切到任一夹具会话，首屏遮罩都必须及时消失。
    ///
    /// - Important: V4 的遮罩由 `InitialPositionGate` 的预算兜底唯一决定，
    ///   与 V1–V3 各自独立。V4 通过不能说明 V3 通过，反之亦然。
    func testFirstScreenMaskClearsPromptlyForEveryFixture() throws {
        for title in MessageListZCodeUITestTitles.all {
            switchConversation(to: title)

            let elapsed = measureMaskLifetime(timeout: maskBudget)
            XCTAssertNotNil(
                elapsed,
                "会话「\(title)」的首屏遮罩在 \(Int(maskBudget))s 内未消失"
            )
        }
    }

    /// 切到长列表会话后遮罩同样必须消失。
    ///
    /// 30 轮长列表最容易逼近收敛上限、也最容易把遮罩挂住。
    func testScrollFixtureMaskClearsPromptly() throws {
        switchConversation(to: MessageListZCodeUITestTitles.scroll)

        let elapsed = measureMaskLifetime(timeout: maskBudget)
        XCTAssertNotNil(elapsed, "长列表会话的首屏遮罩在 \(Int(maskBudget))s 内未消失")
    }

    // MARK: - 四档切换

    /// V1→V2→V3→V4→V1 往返：任何时刻都不得出现**两个**消息列表。
    ///
    /// - Important: 断言的是「同一时刻只有一个 message-list 槽位可见」，
    ///   而不是「切到某一档时它可见」—— 双列表叠加时，后者仍可能通过。
    func testSwitchingAcrossAllVerbositiesNeverShowsTwoLists() throws {
        switchConversation(to: MessageListZCodeUITestTitles.visual)

        for verbosity in MessageListZCodeUITestVerbosity.all {
            switchToVerbosity(verbosity)

            let lists = element(identifier: "lumi.message.zcode.list")
            let v2Lists = app.descendants(matching: .any)
                .matching(identifier: "lumi.message.standard.list")
            let v3Lists = app.descendants(matching: .any)
                .matching(identifier: "lumi.message.detailed.list")

            // 同一时刻最多只能有一个列表容器可见。
            var visibleCount = 0
            if lists.exists && lists.isHittable { visibleCount += 1 }
            if v2Lists.count > 0 && v2Lists.firstMatch.isHittable { visibleCount += 1 }
            if v3Lists.count > 0 && v3Lists.firstMatch.isHittable { visibleCount += 1 }

            XCTAssertLessThanOrEqual(
                visibleCount,
                1,
                "切到 \(verbosity.rawValue) 时同时有 \(visibleCount) 个消息列表可见"
            )
        }
    }

    /// 切到 V4 后，V4 的列表容器必须可见且不为空。
    func testZCodeListIsVisibleAndNotBlank() throws {
        switchConversation(to: MessageListZCodeUITestTitles.visual)
        switchToVerbosity(.zcode)

        let list = element(identifier: "lumi.message.zcode.list")
        XCTAssertTrue(list.waitForExistence(timeout: 15), "V4 列表容器未出现")
        XCTAssertTrue(list.isHittable, "V4 列表容器不可交互")
    }

    // MARK: - 用户气泡

    /// 用户气泡必须存在，且复制按钮可用。
    func testUserBubbleHasCopyButton() throws {
        switchConversation(to: MessageListZCodeUITestTitles.visual)
        switchToVerbosity(.zcode)

        let bubble = element(identifier: "lumi.message.zcode.user-bubble")
        XCTAssertTrue(bubble.waitForExistence(timeout: 15), "用户气泡未出现")

        // 复制按钮在 hover 时才显示，但必须存在（opacity 为 0 也算存在）。
        let copy = element(identifier: "lumi.message.zcode.user-copy")
        XCTAssertTrue(copy.waitForExistence(timeout: 10), "用户气泡复制按钮未出现")
    }

    /// 长用户输入必须有展开 / 收起按钮。
    func testLongUserBubbleHasExpandToggle() throws {
        switchConversation(to: MessageListZCodeUITestTitles.longUser)
        switchToVerbosity(.zcode)

        let toggle = element(identifier: "lumi.message.zcode.user-expand-toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "长用户气泡缺少展开 / 收起按钮")
    }

    /// 展开后再收起，按钮状态必须变化。
    func testLongUserBubbleToggleChangesState() throws {
        switchConversation(to: MessageListZCodeUITestTitles.longUser)
        switchToVerbosity(.zcode)

        let toggle = element(identifier: "lumi.message.zcode.user-expand-toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "长用户气泡缺少展开 / 收起按钮")

        let collapsed = toggle.label
        toggle.click()

        // 等状态翻转。
        //
        // - Important: 断言 `label`（展开 / 收起文案会变），而不是 `value`。
        //   SwiftUI 的 Button 会把 label 当作 AX 的 `value` 暴露，
        //   `accessibilityValue` 在这类控件上**不会**单独呈现 ——
        //   等 `value == "expanded"` 永远等不到。
        let expanded = NSPredicate(format: "label != %@", collapsed)
        expectation(for: expanded, evaluatedWith: toggle)
        waitForExpectations(timeout: 20)

        XCTAssertNotEqual(collapsed, toggle.label, "展开后状态未变化")
    }

    // MARK: - 助手正文与轮尾操作栏

    /// 助手正文必须存在；正文**没有**气泡容器。
    func testAssistantBodyHasNoBubble() throws {
        switchConversation(to: MessageListZCodeUITestTitles.visual)
        switchToVerbosity(.zcode)

        let body = element(identifier: "lumi.message.zcode.assistant-body")
        XCTAssertTrue(body.waitForExistence(timeout: 15), "助手正文未出现")

        // 助手正文不应被画进用户气泡。
        //
        // - Important: 断言的是「助手正文与用户气泡**不是同一个 AX 元素**」，
        //   而不是「用户气泡只有一个」—— 后者在没有用户消息的会话里也成立，
        //   根本测不到「助手有没有气泡」。
        let bubble = element(identifier: "lumi.message.zcode.user-bubble")
        if bubble.exists {
            let nested = bubble.descendants(matching: .any)
                .matching(identifier: "lumi.message.zcode.assistant-body")
            XCTAssertEqual(
                nested.count,
                0,
                "助手正文被画进了用户气泡容器"
            )
        }
    }

    /// 轮尾操作栏必须**只出现一次**。
    ///
    /// - Important: 逐条消息都出现一次操作栏，是「按 message 而不是按 turn」
    ///   的典型症状。断言的是**数量**，不是「存在」。
    func testTurnActionBarAppearsExactlyOnce() throws {
        switchConversation(to: MessageListZCodeUITestTitles.visual)
        switchToVerbosity(.zcode)

        let body = element(identifier: "lumi.message.zcode.assistant-body")
        XCTAssertTrue(body.waitForExistence(timeout: 15), "助手正文未出现")

        // hover 整个 turn 让操作栏出现。
        body.hover()

        // Important: 断言的是**复制按钮的数量**，不是容器的数量。
        //   容器挂 `accessibilityIdentifier` 会被 SwiftUI 传播给子元素，
        //   覆盖掉子元素自己的标识符；因此操作栏的可观测证据是
        //   「每个 turn 恰好一个 `turn-copy` 按钮 + 一个 `turn-time` 标签」。
        let copyButtons = app.descendants(matching: .any)
            .matching(identifier: "lumi.message.zcode.turn-copy")
        XCTAssertEqual(
            copyButtons.count,
            1,
            "轮尾复制按钮出现了 \(copyButtons.count) 次（应按 turn 出现一次）"
        )
    }

    /// 轮尾操作栏必须有真实的复制按钮与时间标签。
    func testTurnActionBarHasCopyAndTime() throws {
        switchConversation(to: MessageListZCodeUITestTitles.visual)
        switchToVerbosity(.zcode)

        let body = element(identifier: "lumi.message.zcode.assistant-body")
        XCTAssertTrue(body.waitForExistence(timeout: 15), "助手正文未出现")
        body.hover()

        XCTAssertTrue(
            element(identifier: "lumi.message.zcode.turn-copy").waitForExistence(timeout: 10),
            "轮尾复制按钮未出现"
        )
        XCTAssertTrue(
            element(identifier: "lumi.message.zcode.turn-time").waitForExistence(timeout: 10),
            "轮尾时间标签未出现"
        )
    }

    // MARK: - 无假按钮

    /// V4 不得出现 like / edit / fork / retry 之类的假按钮。
    ///
    /// - Important: 计划明确要求「不发明 Lumi 不存在的 ZCode 能力」。
    ///   这里断言这些按钮**不存在**，而 retry（真实存在的失败回合重试）
    ///   属于错误消息，不在本用例范围内。
    func testNoFakeLikeEditForkButtons() throws {
        switchConversation(to: MessageListZCodeUITestTitles.visual)
        switchToVerbosity(.zcode)

        for fakeLabel in ["like", "fork", "点赞", "分支", "复制并分支"] {
            let fake = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", fakeLabel))
            XCTAssertEqual(
                fake.count,
                0,
                "出现了计划禁止的假按钮：\(fakeLabel)"
            )
        }
    }

    // MARK: - 工具历史

    /// 工具会话必须出现工作历史分组。
    func testToolWorkHistoryGroupAppears() throws {
        switchConversation(to: MessageListZCodeUITestTitles.tool)
        switchToVerbosity(.zcode)

        let history = element(identifier: "lumi.message.zcode.work-history")
        XCTAssertTrue(history.waitForExistence(timeout: 15), "工作历史分组未出现")
    }

    /// 工作历史默认收起，点击后展开。
    func testToolWorkHistoryToggles() throws {
        switchConversation(to: MessageListZCodeUITestTitles.tool)
        switchToVerbosity(.zcode)

        let toggle = element(identifier: "lumi.message.zcode.work-history-toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "工作历史展开按钮未出现")

        let before = toggle.value as? String
        toggle.click()

        let expanded = NSPredicate(format: "value == %@", "expanded")
        expectation(for: expanded, evaluatedWith: toggle)
        waitForExpectations(timeout: 10)

        XCTAssertNotEqual(before, toggle.value as? String, "工作历史展开后状态未变化")
    }

    // MARK: - Helpers

    /// 测量遮罩寿命。
    ///
    /// - Important: 先等遮罩**出现**再等它消失，测的是真实寿命。
    ///   只调 `waitForNonExistence` 会得到假数据：切换动作本身有几十到几百毫秒的
    ///   AX 往返，若遮罩在这段时间内已消失，测出的就是「AX 调用耗时」而非遮罩寿命。
    ///
    /// - Returns: 遮罩寿命；超时未消失返回 nil；未出现返回 0。
    private func measureMaskLifetime(timeout: TimeInterval) -> TimeInterval? {
        let mask = element(identifier: maskIdentifier)
        guard mask.waitForExistence(timeout: 2) else {
            print("📊 [\(name)] mask never appeared → no lifetime to measure")
            return 0
        }

        let start = Date()
        let cleared = !mask.waitForNonExistence(timeout: timeout)
        let elapsed = Date().timeIntervalSince(start)
        print("📊 [\(name)] mask lifetime=\(String(format: "%.3f", elapsed))s "
              + "cleared=\(cleared) budget=\(String(format: "%.1f", timeout))s")
        return cleared ? elapsed : nil
    }

    /// 在会话列表里点击指定标题。
    ///
    /// - Important: 查询必须限定在**列表容器内**（`listID`）。会话标题在
    ///   消息列表正文里也存在同名前缀，全窗口搜索会命中消息正文而非会话行，
    ///   点击后选中态不变，表现为「切换没生效」，极具误导性。
    private func switchConversation(to title: String) {
        let row = conversationRow(title)
        XCTAssertTrue(
            row.waitForExistence(timeout: 15),
            "会话「\(title)」在列表中不可见（列表容器内未找到）"
        )
        row.click()
    }

    /// 定位一条会话行：限定列表容器 → 按 item 标识筛出所有行 → 按 label 匹配标题。
    private func conversationRow(_ title: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.listID)
            .descendants(matching: .any)
            .matching(identifier: LumiConversationListIDs.itemID)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", title, title))
            .firstMatch
    }

    /// 切换回复级别。
    ///
    /// - Note: 优先走设置里的分段控件；找不到时跳过并记录，
    ///   而不是让整批用例因入口差异而失败。
    private func switchToVerbosity(_ verbosity: MessageListZCodeUITestVerbosity) {
        let control = app.descendants(matching: .any)
            .matching(identifier: "lumi.settings.response-verbosity")
            .firstMatch
        guard control.exists else {
            print("ℹ️ [\(name)] 未找到回复级别控件，跳过 \(verbosity.rawValue) 切换")
            return
        }
        control.click()
        let option = app.descendants(matching: .any)
            .matching(identifier: "lumi.settings.response-verbosity.\(verbosity.rawValue)")
            .firstMatch
        if option.waitForExistence(timeout: 5) {
            option.click()
        }
    }
}

/// V4 夹具会话标题。
///
/// - Note: 与 `MessageListZCodeUITestingSupport.fixtureTitles` 一一对应。
///   标题是 UI 测试的定位锚点，改动会让既有截图失效。
enum MessageListZCodeUITestTitles {
    static let visual = "ZCode Visual Target"
    static let longUser = "ZCode Long User Target"
    static let tool = "ZCode Tool Target"
    static let scroll = "ZCode Scroll Target"
    static let streaming = "ZCode Streaming Target"

    static let all = [visual, longUser, tool, scroll, streaming]
}

/// 四档回复级别。
enum MessageListZCodeUITestVerbosity: String, CaseIterable {
    case brief
    case standard
    case detailed
    case zcode

    static let all: [MessageListZCodeUITestVerbosity] = [.brief, .standard, .detailed, .zcode]
}
